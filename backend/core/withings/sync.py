import logging
from datetime import datetime, timedelta
from typing import List

from sqlalchemy.orm import Session

from backend.core.models import DataSourceConnection, DataSyncLog, HealthMetric, WithingsMeasurement
from .client import WithingsClient
from backend.core.config import WITHINGS_SYNC_CONFIG
from .models import (
    WithingsMeasurement as WithingsMeasurementModel,
    WithingsActivity,
    WithingsSleep,
    WithingsTokenData,
)

logger = logging.getLogger(__name__)

class WithingsSyncService:
    def __init__(self, db: Session):
        self.db = db
        self.client = WithingsClient()
        self.sync_config = WITHINGS_SYNC_CONFIG

    async def sync_connection(self, connection: DataSourceConnection) -> DataSyncLog:
        """Synchronize data for a Withings connection."""
        sync_log = DataSyncLog(
            connection_id=connection.id,
            started_at=datetime.utcnow(),
            status="in_progress"
        )
        self.db.add(sync_log)
        self.db.commit()

        try:
            # Get last sync time or default to 30 days ago
            last_sync = (
                self.db.query(DataSyncLog)
                .filter(
                    DataSyncLog.connection_id == connection.id,
                    DataSyncLog.status == "completed"
                )
                .order_by(DataSyncLog.completed_at.desc())
                .first()
            )
            
            start_date = (
                last_sync.completed_at if last_sync
                else datetime.utcnow() - timedelta(days=30)
            )
            end_date = datetime.utcnow()

            # Check if token needs refresh
            access_token = connection.access_token
            if connection.token_expires_at and connection.token_expires_at <= datetime.utcnow():
                # Refresh token
                new_token_data = await self.client.refresh_token(connection.refresh_token)
                connection.access_token = new_token_data["access_token"]
                connection.refresh_token = new_token_data["refresh_token"]
                connection.token_expires_at = datetime.fromtimestamp(
                    datetime.utcnow().timestamp() + new_token_data["expires_in"]
                )
                access_token = new_token_data["access_token"]
                self.db.commit()

            # Sync measurements
            measurements_count = await self._sync_measurements(
                connection,
                access_token,
                start_date,
                end_date
            )

            # Sync activities
            activities_count = await self._sync_activities(
                connection,
                access_token,
                start_date,
                end_date
            )

            # Sync sleep data
            sleep_count = await self._sync_sleep(
                connection,
                access_token,
                start_date,
                end_date
            )

            sync_log.status = "completed"
            sync_log.end_time = datetime.utcnow()
            sync_log.metrics_synced = {
                "measurements": measurements_count,
                "activities": activities_count,
                "sleep": sleep_count,
                "total": measurements_count + activities_count + sleep_count
            }
            sync_log.error_message = None

        except Exception as e:
            logger.error(f"Error syncing Withings data: {str(e)}")
            sync_log.status = "failed"
            sync_log.end_time = datetime.utcnow()
            sync_log.error_message = str(e)

        self.db.commit()
        return sync_log

    async def _sync_measurements(
        self,
        connection: DataSourceConnection,
        access_token: str,
        start_date: datetime,
        end_date: datetime
    ) -> int:
        """Sync measurements from Withings."""
        count = 0
        try:
            response = await self.client.get_measurements(
                access_token,
                start_date,
                end_date
            )

            for measure in response.get("body", {}).get("measuregrps", []):
                for measure_data in measure.get("measures", []):
                    # Save to WithingsMeasurement table
                    withings_measurement = WithingsMeasurement(
                        connection_id=connection.id,
                        timestamp=datetime.fromtimestamp(measure["date"]),
                        type=self._get_measurement_type(measure_data["type"]),
                        value=measure_data["value"] * (10 ** measure_data["unit"]),
                        unit=self._get_unit(measure_data["type"]),
                        device_id=measure.get("deviceid"),
                        raw_data=measure
                    )
                    self.db.add(withings_measurement)
                    
                    # Also save to HealthMetric table for unified access
                    health_metric = HealthMetric(
                        user_id=connection.user_id,
                        metric_type=self._get_measurement_type(measure_data["type"]),
                        value=measure_data["value"] * (10 ** measure_data["unit"]),
                        source="withings",
                        timestamp=datetime.fromtimestamp(measure["date"]),
                        meta={
                            "unit": self._get_unit(measure_data["type"]),
                            "device_id": measure.get("deviceid"),
                            "withings_measurement_id": str(withings_measurement.id)
                        }
                    )
                    self.db.add(health_metric)
                    count += 1

            self.db.commit()

        except Exception as e:
            logger.error(f"Error syncing measurements: {str(e)}")
            self.db.rollback()
            raise

        return count

    async def _sync_activities(
        self,
        connection: DataSourceConnection,
        access_token: str,
        start_date: datetime,
        end_date: datetime
    ) -> int:
        """Sync activities from Withings."""
        count = 0
        try:
            response = await self.client.get_activities(
                access_token,
                start_date,
                end_date
            )

            for activity in response.get("body", {}).get("activities", []):
                activity_date = datetime.fromtimestamp(activity["date"])
                
                # Save individual metrics as HealthMetrics
                metrics = [
                    ("steps", activity.get("steps", 0), "count"),
                    ("distance", activity.get("distance", 0), "meters"),
                    ("calories", activity.get("calories", 0), "kcal"),
                    ("elevation", activity.get("elevation", 0), "meters"),
                    ("active_time", activity.get("active", 0), "seconds"),
                ]
                
                for metric_type, value, unit in metrics:
                    if value > 0:  # Only save non-zero values
                        health_metric = HealthMetric(
                            user_id=connection.user_id,
                            metric_type=metric_type,
                            value=float(value),
                            source="withings",
                            timestamp=activity_date,
                            meta={
                                "unit": unit,
                                "device_id": activity.get("deviceid"),
                                "activity_data": activity
                            }
                        )
                        self.db.add(health_metric)
                        count += 1

            self.db.commit()

        except Exception as e:
            logger.error(f"Error syncing activities: {str(e)}")
            self.db.rollback()
            raise

        return count

    async def _sync_sleep(
        self,
        connection: DataSourceConnection,
        access_token: str,
        start_date: datetime,
        end_date: datetime
    ) -> int:
        """Sync sleep data from Withings."""
        count = 0
        try:
            response = await self.client.get_sleep(
                access_token,
                start_date,
                end_date
            )

            for sleep in response.get("body", {}).get("series", []):
                sleep_start = datetime.fromtimestamp(sleep["startdate"])
                
                # Save individual sleep metrics as HealthMetrics
                metrics = [
                    ("sleep_duration", sleep["duration"], "seconds"),
                    ("deep_sleep_duration", sleep.get("deepsleepduration", 0), "seconds"),
                    ("light_sleep_duration", sleep.get("lightsleepduration", 0), "seconds"),
                    ("rem_sleep_duration", sleep.get("remsleepduration", 0), "seconds"),
                    ("wake_duration", sleep.get("wakeupduration", 0), "seconds"),
                ]
                
                if sleep.get("sleep_score"):
                    metrics.append(("sleep_score", sleep["sleep_score"], "score"))
                
                for metric_type, value, unit in metrics:
                    if value > 0:  # Only save non-zero values
                        health_metric = HealthMetric(
                            user_id=connection.user_id,
                            metric_type=metric_type,
                            value=float(value),
                            source="withings",
                            timestamp=sleep_start,
                            meta={
                                "unit": unit,
                                "device_id": sleep.get("deviceid"),
                                "sleep_end_time": datetime.fromtimestamp(sleep["enddate"]).isoformat(),
                                "sleep_data": sleep
                            }
                        )
                        self.db.add(health_metric)
                        count += 1

            self.db.commit()

        except Exception as e:
            logger.error(f"Error syncing sleep data: {str(e)}")
            self.db.rollback()
            raise

        return count

    def _get_unit(self, measure_type: int) -> str:
        """Convert Withings measure type to unit."""
        units = {
            1: "kg",  # weight
            4: "kg",  # fat mass
            5: "kg",  # fat free mass
            6: "%",   # fat ratio
            8: "kg",  # muscle mass
            9: "%",   # muscle mass ratio
            11: "%",  # hydration
            12: "kg", # bone mass
        }
        return units.get(measure_type, "unknown")

    def _get_measurement_type(self, measure_type: int) -> str:
        """Convert Withings measure type to measurement type."""
        types = {
            1: "weight",
            4: "fat_mass",
            5: "fat_free_mass",
            6: "fat_ratio",
            8: "muscle_mass",
            9: "muscle_mass_ratio",
            11: "hydration",
            12: "bone_mass",
        }
        return types.get(measure_type, "unknown") 
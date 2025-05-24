import logging
from datetime import datetime, timedelta
from typing import List

from sqlalchemy.orm import Session

from backend.core.models import DataSourceConnection, DataSyncLog
from .client import WithingsClient
from .config import WITHINGS_SYNC_CONFIG
from .models import (
    WithingsMeasurement,
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

            # Refresh token if needed
            token_data = WithingsTokenData(**connection.credentials)
            if token_data.expires_at <= datetime.utcnow():
                new_token_data = await self.client.refresh_token(token_data.refresh_token)
                token_data = WithingsTokenData(**new_token_data)
                connection.credentials = token_data.dict()
                self.db.commit()

            # Sync measurements
            measurements = await self._sync_measurements(
                connection,
                token_data,
                start_date,
                end_date
            )

            # Sync activities
            activities = await self._sync_activities(
                connection,
                token_data,
                start_date,
                end_date
            )

            # Sync sleep data
            sleep_data = await self._sync_sleep(
                connection,
                token_data,
                start_date,
                end_date
            )

            sync_log.status = "completed"
            sync_log.completed_at = datetime.utcnow()
            sync_log.metrics_synced = len(measurements) + len(activities) + len(sleep_data)
            sync_log.error_message = None

        except Exception as e:
            logger.error(f"Error syncing Withings data: {str(e)}")
            sync_log.status = "failed"
            sync_log.completed_at = datetime.utcnow()
            sync_log.error_message = str(e)

        self.db.commit()
        return sync_log

    async def _sync_measurements(
        self,
        connection: DataSourceConnection,
        token_data: WithingsTokenData,
        start_date: datetime,
        end_date: datetime
    ) -> List[WithingsMeasurement]:
        """Sync measurements from Withings."""
        measurements = []
        try:
            response = await self.client.get_measurements(
                token_data.access_token,
                start_date,
                end_date
            )

            for measure in response.get("body", {}).get("measuregrps", []):
                for measure_data in measure.get("measures", []):
                    measurement = WithingsMeasurement(
                        timestamp=datetime.fromtimestamp(measure["date"]),
                        value=measure_data["value"] * (10 ** measure_data["unit"]),
                        unit=self._get_unit(measure_data["type"]),
                        type=self._get_measurement_type(measure_data["type"]),
                        category="body",
                        device_id=measure.get("deviceid"),
                        raw_data=measure
                    )
                    measurements.append(measurement)

        except Exception as e:
            logger.error(f"Error syncing measurements: {str(e)}")
            raise

        return measurements

    async def _sync_activities(
        self,
        connection: DataSourceConnection,
        token_data: WithingsTokenData,
        start_date: datetime,
        end_date: datetime
    ) -> List[WithingsActivity]:
        """Sync activities from Withings."""
        activities = []
        try:
            response = await self.client.get_activities(
                token_data.access_token,
                start_date,
                end_date
            )

            for activity in response.get("body", {}).get("activities", []):
                activity_data = WithingsActivity(
                    date=datetime.fromtimestamp(activity["date"]),
                    steps=activity.get("steps", 0),
                    distance=activity.get("distance", 0),
                    calories=activity.get("calories", 0),
                    elevation=activity.get("elevation", 0),
                    active_time=activity.get("active", 0),
                    device_id=activity.get("deviceid"),
                    raw_data=activity
                )
                activities.append(activity_data)

        except Exception as e:
            logger.error(f"Error syncing activities: {str(e)}")
            raise

        return activities

    async def _sync_sleep(
        self,
        connection: DataSourceConnection,
        token_data: WithingsTokenData,
        start_date: datetime,
        end_date: datetime
    ) -> List[WithingsSleep]:
        """Sync sleep data from Withings."""
        sleep_data = []
        try:
            response = await self.client.get_sleep(
                token_data.access_token,
                start_date,
                end_date
            )

            for sleep in response.get("body", {}).get("series", []):
                sleep_entry = WithingsSleep(
                    start_time=datetime.fromtimestamp(sleep["startdate"]),
                    end_time=datetime.fromtimestamp(sleep["enddate"]),
                    duration=sleep["duration"],
                    deep_sleep_duration=sleep.get("deepsleepduration", 0),
                    light_sleep_duration=sleep.get("lightsleepduration", 0),
                    rem_sleep_duration=sleep.get("remsleepduration", 0),
                    wake_duration=sleep.get("wakeupduration", 0),
                    sleep_score=sleep.get("sleep_score"),
                    device_id=sleep.get("deviceid"),
                    raw_data=sleep
                )
                sleep_data.append(sleep_entry)

        except Exception as e:
            logger.error(f"Error syncing sleep data: {str(e)}")
            raise

        return sleep_data

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
"""
Anomaly Detector - Health Data Anomaly Detection

This module detects anomalies and unusual patterns in health data that may
indicate health issues, data quality problems, or significant changes in
user behavior that warrant attention.
"""

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
from typing import Dict, List, Any, Optional
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class AnomalyDetector:
    """
    Detects anomalies and unusual patterns in health data
    """
    
    def __init__(self):
        self.min_data_points = 14  # Minimum data points for anomaly detection
        self.contamination_rate = 0.1  # Expected proportion of anomalies
        self.z_score_threshold = 2.5  # Z-score threshold for statistical anomalies
        
    def detect_anomalies(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Detect anomalies across all health metrics
        
        Args:
            health_data: DataFrame with health metrics
            
        Returns:
            List of detected anomalies
        """
        anomalies = []
        
        try:
            # Get unique metrics
            metrics = health_data['metric_type'].unique()
            
            for metric in metrics:
                metric_data = health_data[health_data['metric_type'] == metric].copy()
                
                if len(metric_data) >= self.min_data_points:
                    # Statistical anomalies
                    stat_anomalies = self._detect_statistical_anomalies(metric_data, metric)
                    anomalies.extend(stat_anomalies)
                    
                    # Machine learning anomalies
                    ml_anomalies = self._detect_ml_anomalies(metric_data, metric)
                    anomalies.extend(ml_anomalies)
                    
                    # Pattern-based anomalies
                    pattern_anomalies = self._detect_pattern_anomalies(metric_data, metric)
                    anomalies.extend(pattern_anomalies)
            
            # Sort by severity and date
            anomalies.sort(key=lambda x: (x['severity'], x['date']), reverse=True)
            
        except Exception as e:
            logger.error(f"Error detecting anomalies: {str(e)}")
        
        return anomalies
    
    def detect_health_alerts(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Detect health-related alerts that may require immediate attention
        
        Args:
            health_data: DataFrame with health metrics
            
        Returns:
            List of health alerts
        """
        alerts = []
        
        try:
            # Heart rate alerts
            hr_alerts = self._detect_heart_rate_alerts(health_data)
            alerts.extend(hr_alerts)
            
            # Sleep alerts
            sleep_alerts = self._detect_sleep_alerts(health_data)
            alerts.extend(sleep_alerts)
            
            # Activity alerts
            activity_alerts = self._detect_activity_alerts(health_data)
            alerts.extend(activity_alerts)
            
            # Weight alerts
            weight_alerts = self._detect_weight_alerts(health_data)
            alerts.extend(weight_alerts)
            
        except Exception as e:
            logger.error(f"Error detecting health alerts: {str(e)}")
        
        return alerts
    
    def _detect_statistical_anomalies(self, metric_data: pd.DataFrame, metric: str) -> List[Dict[str, Any]]:
        """Detect anomalies using statistical methods (Z-score)"""
        anomalies = []
        
        try:
            # Sort by date
            metric_data = metric_data.sort_values('recorded_at')
            
            # Calculate Z-scores
            values = metric_data['value'].values
            z_scores = np.abs(stats.zscore(values))
            
            # Find anomalies
            anomaly_indices = np.where(z_scores > self.z_score_threshold)[0]
            
            for idx in anomaly_indices:
                row = metric_data.iloc[idx]
                z_score = z_scores[idx]
                
                # Calculate deviation percentage
                mean_value = values.mean()
                deviation = abs(row['value'] - mean_value) / mean_value * 100
                
                anomalies.append({
                    'metric': metric,
                    'date': row['recorded_at'].date(),
                    'value': row['value'],
                    'expected_range': f"{mean_value - 2*values.std():.1f} - {mean_value + 2*values.std():.1f}",
                    'deviation': deviation,
                    'z_score': z_score,
                    'severity': self._calculate_severity(z_score, 'statistical'),
                    'confidence': min(1.0, z_score / 5.0),
                    'type': 'statistical',
                    'description': f"Unusual {metric.replace('_', ' ')} value detected",
                    'recommendations': self._generate_anomaly_recommendations(metric, deviation, 'statistical')
                })
                
        except Exception as e:
            logger.error(f"Error detecting statistical anomalies for {metric}: {str(e)}")
        
        return anomalies
    
    def _detect_ml_anomalies(self, metric_data: pd.DataFrame, metric: str) -> List[Dict[str, Any]]:
        """Detect anomalies using machine learning (Isolation Forest)"""
        anomalies = []
        
        try:
            if len(metric_data) < 20:  # Need more data for ML
                return anomalies
            
            # Prepare features
            metric_data = metric_data.sort_values('recorded_at')
            metric_data['hour'] = pd.to_datetime(metric_data['recorded_at']).dt.hour
            metric_data['day_of_week'] = pd.to_datetime(metric_data['recorded_at']).dt.dayofweek
            
            # Create feature matrix
            features = ['value', 'hour', 'day_of_week']
            X = metric_data[features].values
            
            # Scale features
            scaler = StandardScaler()
            X_scaled = scaler.fit_transform(X)
            
            # Fit Isolation Forest
            iso_forest = IsolationForest(
                contamination=self.contamination_rate,
                random_state=42
            )
            anomaly_labels = iso_forest.fit_predict(X_scaled)
            
            # Get anomaly scores
            anomaly_scores = iso_forest.decision_function(X_scaled)
            
            # Find anomalies
            anomaly_indices = np.where(anomaly_labels == -1)[0]
            
            for idx in anomaly_indices:
                row = metric_data.iloc[idx]
                score = abs(anomaly_scores[idx])
                
                # Calculate deviation from median
                median_value = metric_data['value'].median()
                deviation = abs(row['value'] - median_value) / median_value * 100
                
                anomalies.append({
                    'metric': metric,
                    'date': row['recorded_at'].date(),
                    'value': row['value'],
                    'anomaly_score': score,
                    'deviation': deviation,
                    'severity': self._calculate_severity(score, 'ml'),
                    'confidence': min(1.0, score),
                    'type': 'pattern',
                    'description': f"Unusual pattern detected in {metric.replace('_', ' ')}",
                    'recommendations': self._generate_anomaly_recommendations(metric, deviation, 'pattern')
                })
                
        except Exception as e:
            logger.error(f"Error detecting ML anomalies for {metric}: {str(e)}")
        
        return anomalies
    
    def _detect_pattern_anomalies(self, metric_data: pd.DataFrame, metric: str) -> List[Dict[str, Any]]:
        """Detect pattern-based anomalies (sudden changes, missing data)"""
        anomalies = []
        
        try:
            # Sort by date
            metric_data = metric_data.sort_values('recorded_at')
            
            # Detect sudden changes
            sudden_changes = self._detect_sudden_changes(metric_data, metric)
            anomalies.extend(sudden_changes)
            
            # Detect data gaps
            data_gaps = self._detect_data_gaps(metric_data, metric)
            anomalies.extend(data_gaps)
            
        except Exception as e:
            logger.error(f"Error detecting pattern anomalies for {metric}: {str(e)}")
        
        return anomalies
    
    def _detect_sudden_changes(self, metric_data: pd.DataFrame, metric: str) -> List[Dict[str, Any]]:
        """Detect sudden changes in metric values"""
        anomalies = []
        
        try:
            if len(metric_data) < 3:
                return anomalies
            
            # Calculate day-to-day changes
            metric_data['value_change'] = metric_data['value'].diff()
            metric_data['percent_change'] = metric_data['value'].pct_change() * 100
            
            # Find sudden changes (>50% change from previous day)
            sudden_change_threshold = 50
            sudden_changes = metric_data[
                abs(metric_data['percent_change']) > sudden_change_threshold
            ]
            
            for _, row in sudden_changes.iterrows():
                if pd.notna(row['percent_change']):
                    anomalies.append({
                        'metric': metric,
                        'date': row['recorded_at'].date(),
                        'value': row['value'],
                        'previous_value': row['value'] - row['value_change'],
                        'percent_change': row['percent_change'],
                        'deviation': abs(row['percent_change']),
                        'severity': self._calculate_severity(abs(row['percent_change']) / 100, 'sudden_change'),
                        'confidence': min(1.0, abs(row['percent_change']) / 100),
                        'type': 'sudden_change',
                        'description': f"Sudden {abs(row['percent_change']):.1f}% change in {metric.replace('_', ' ')}",
                        'recommendations': self._generate_sudden_change_recommendations(metric, row['percent_change'])
                    })
                    
        except Exception as e:
            logger.error(f"Error detecting sudden changes for {metric}: {str(e)}")
        
        return anomalies
    
    def _detect_data_gaps(self, metric_data: pd.DataFrame, metric: str) -> List[Dict[str, Any]]:
        """Detect significant gaps in data collection"""
        anomalies = []
        
        try:
            # Sort by date
            metric_data = metric_data.sort_values('recorded_at')
            
            # Calculate time differences between consecutive readings
            metric_data['time_diff'] = metric_data['recorded_at'].diff()
            
            # Find gaps longer than 3 days
            gap_threshold = timedelta(days=3)
            gaps = metric_data[metric_data['time_diff'] > gap_threshold]
            
            for _, row in gaps.iterrows():
                gap_days = row['time_diff'].days
                
                anomalies.append({
                    'metric': metric,
                    'date': row['recorded_at'].date(),
                    'gap_duration': gap_days,
                    'severity': min(1.0, gap_days / 14),  # Max severity at 2 weeks
                    'confidence': 1.0,
                    'type': 'data_gap',
                    'description': f"{gap_days}-day gap in {metric.replace('_', ' ')} data",
                    'recommendations': [
                        "Check if your tracking device is working properly",
                        "Ensure consistent data syncing",
                        "Consider manual data entry for missing periods"
                    ]
                })
                
        except Exception as e:
            logger.error(f"Error detecting data gaps for {metric}: {str(e)}")
        
        return anomalies
    
    def _detect_heart_rate_alerts(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Detect heart rate-related health alerts"""
        alerts = []
        
        try:
            # Resting heart rate alerts
            resting_hr_data = health_data[health_data['metric_type'] == 'heart_rate_resting']
            
            if not resting_hr_data.empty:
                recent_hr = resting_hr_data.nlargest(7, 'recorded_at')['value'].mean()
                
                if recent_hr > 100:
                    alerts.append({
                        'type': 'high_resting_hr',
                        'metric': 'heart_rate_resting',
                        'value': recent_hr,
                        'severity': min(1.0, (recent_hr - 100) / 50),
                        'description': f"Your resting heart rate has been elevated at {recent_hr:.0f} bpm",
                        'recommendations': [
                            "Consider consulting with a healthcare provider",
                            "Monitor stress levels and sleep quality",
                            "Avoid caffeine and alcohol before measurements"
                        ]
                    })
                elif recent_hr < 50:
                    alerts.append({
                        'type': 'low_resting_hr',
                        'metric': 'heart_rate_resting',
                        'value': recent_hr,
                        'severity': min(1.0, (50 - recent_hr) / 30),
                        'description': f"Your resting heart rate is quite low at {recent_hr:.0f} bpm",
                        'recommendations': [
                            "This may be normal for athletes, but consider medical consultation if you're not highly trained",
                            "Monitor for symptoms like dizziness or fatigue"
                        ]
                    })
            
        except Exception as e:
            logger.error(f"Error detecting heart rate alerts: {str(e)}")
        
        return alerts
    
    def _detect_sleep_alerts(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Detect sleep-related health alerts"""
        alerts = []
        
        try:
            sleep_data = health_data[health_data['metric_type'] == 'sleep_duration']
            
            if not sleep_data.empty:
                recent_sleep = sleep_data.nlargest(7, 'recorded_at')['value'].mean()
                
                if recent_sleep < 6:
                    alerts.append({
                        'type': 'insufficient_sleep',
                        'metric': 'sleep_duration',
                        'value': recent_sleep,
                        'severity': min(1.0, (6 - recent_sleep) / 3),
                        'description': f"You're averaging only {recent_sleep:.1f} hours of sleep",
                        'recommendations': [
                            "Aim for 7-9 hours of sleep per night",
                            "Establish a consistent bedtime routine",
                            "Limit screen time before bed"
                        ]
                    })
                elif recent_sleep > 10:
                    alerts.append({
                        'type': 'excessive_sleep',
                        'metric': 'sleep_duration',
                        'value': recent_sleep,
                        'severity': min(1.0, (recent_sleep - 10) / 4),
                        'description': f"You're sleeping an average of {recent_sleep:.1f} hours",
                        'recommendations': [
                            "Excessive sleep may indicate underlying health issues",
                            "Consider consulting with a healthcare provider",
                            "Evaluate sleep quality, not just quantity"
                        ]
                    })
            
        except Exception as e:
            logger.error(f"Error detecting sleep alerts: {str(e)}")
        
        return alerts
    
    def _detect_activity_alerts(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Detect activity-related health alerts"""
        alerts = []
        
        try:
            steps_data = health_data[health_data['metric_type'] == 'activity_steps']
            
            if not steps_data.empty:
                recent_steps = steps_data.nlargest(7, 'recorded_at')['value'].mean()
                
                if recent_steps < 3000:
                    alerts.append({
                        'type': 'low_activity',
                        'metric': 'activity_steps',
                        'value': recent_steps,
                        'severity': min(1.0, (3000 - recent_steps) / 3000),
                        'description': f"Your activity level is low with {recent_steps:.0f} daily steps",
                        'recommendations': [
                            "Try to increase daily movement gradually",
                            "Take short walks throughout the day",
                            "Consider setting smaller, achievable step goals"
                        ]
                    })
            
        except Exception as e:
            logger.error(f"Error detecting activity alerts: {str(e)}")
        
        return alerts
    
    def _detect_weight_alerts(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Detect weight-related health alerts"""
        alerts = []
        
        try:
            weight_data = health_data[health_data['metric_type'] == 'body_weight']
            
            if len(weight_data) >= 14:  # Need at least 2 weeks of data
                weight_data = weight_data.sort_values('recorded_at')
                
                # Calculate recent trend
                recent_weights = weight_data.tail(14)
                weight_change = recent_weights['value'].iloc[-1] - recent_weights['value'].iloc[0]
                percent_change = (weight_change / recent_weights['value'].iloc[0]) * 100
                
                if abs(percent_change) > 5:  # >5% change in 2 weeks
                    direction = "gain" if weight_change > 0 else "loss"
                    alerts.append({
                        'type': f'rapid_weight_{direction}',
                        'metric': 'body_weight',
                        'value': abs(weight_change),
                        'percent_change': abs(percent_change),
                        'severity': min(1.0, abs(percent_change) / 10),
                        'description': f"Rapid weight {direction} of {abs(weight_change):.1f} lbs ({abs(percent_change):.1f}%) in 2 weeks",
                        'recommendations': [
                            "Rapid weight changes may indicate health issues",
                            "Consider consulting with a healthcare provider",
                            "Review recent diet and exercise changes"
                        ]
                    })
            
        except Exception as e:
            logger.error(f"Error detecting weight alerts: {str(e)}")
        
        return alerts
    
    def _calculate_severity(self, value: float, anomaly_type: str) -> float:
        """Calculate severity score for an anomaly"""
        if anomaly_type == 'statistical':
            # Z-score based severity
            return min(1.0, value / 5.0)
        elif anomaly_type == 'ml':
            # ML score based severity
            return min(1.0, value)
        elif anomaly_type == 'sudden_change':
            # Percent change based severity
            return min(1.0, value / 2.0)
        else:
            return 0.5  # Default moderate severity
    
    def _generate_anomaly_recommendations(self, metric: str, deviation: float, anomaly_type: str) -> List[str]:
        """Generate recommendations based on detected anomalies"""
        recommendations = []
        
        if anomaly_type == 'statistical':
            recommendations.append(f"This {metric.replace('_', ' ')} reading is {deviation:.1f}% different from your typical range")
            
            if metric == 'heart_rate_resting':
                recommendations.extend([
                    "Check if you were stressed, ill, or had caffeine before measurement",
                    "Monitor for additional symptoms",
                    "Consider consulting healthcare provider if pattern continues"
                ])
            elif metric == 'sleep_duration':
                recommendations.extend([
                    "Review what might have affected your sleep that night",
                    "Check for environmental factors (noise, temperature, light)",
                    "Consider sleep hygiene improvements"
                ])
            elif metric == 'activity_steps':
                recommendations.extend([
                    "Reflect on what made this day different from your usual routine",
                    "Consider if illness, weather, or schedule changes affected activity"
                ])
        
        recommendations.append("Continue monitoring this metric closely")
        return recommendations
    
    def _generate_sudden_change_recommendations(self, metric: str, percent_change: float) -> List[str]:
        """Generate recommendations for sudden changes"""
        direction = "increase" if percent_change > 0 else "decrease"
        
        recommendations = [
            f"Sudden {direction} of {abs(percent_change):.1f}% detected in {metric.replace('_', ' ')}"
        ]
        
        if metric == 'body_weight':
            recommendations.extend([
                "Sudden weight changes may be due to hydration, medication, or measurement errors",
                "Weigh yourself at the same time of day for consistency",
                "Consider if recent diet or exercise changes could explain this"
            ])
        elif metric == 'heart_rate_resting':
            recommendations.extend([
                "Sudden heart rate changes may indicate stress, illness, or medication effects",
                "Monitor for additional symptoms",
                "Ensure consistent measurement conditions"
            ])
        
        return recommendations 
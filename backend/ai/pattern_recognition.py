"""
Pattern Recognition - Health Data Pattern and Trend Analysis

This module identifies patterns and trends in health data, including seasonal patterns,
weekly cycles, improvement trends, and behavioral patterns across different metrics.
"""

import numpy as np
import pandas as pd
from scipy import stats
from sklearn.linear_model import LinearRegression
from typing import Dict, List, Any, Optional
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class PatternRecognizer:
    """
    Identifies patterns and trends in health data
    """
    
    def __init__(self):
        self.min_data_points = 7
        self.trend_significance_threshold = 0.05
        
    def analyze_trends(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Analyze trends in health metrics over time
        
        Args:
            health_data: DataFrame with health metrics
            
        Returns:
            List of trend analyses
        """
        trends = []
        
        try:
            # Get unique metrics
            metrics = health_data['metric_type'].unique()
            
            for metric in metrics:
                metric_data = health_data[health_data['metric_type'] == metric].copy()
                
                if len(metric_data) >= self.min_data_points:
                    trend_analysis = self._analyze_metric_trend(metric_data, metric)
                    if trend_analysis:
                        trends.append(trend_analysis)
            
        except Exception as e:
            logger.error(f"Error analyzing trends: {str(e)}")
        
        return trends
    
    def identify_patterns(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Identify various patterns in health data
        
        Args:
            health_data: DataFrame with health metrics
            
        Returns:
            List of identified patterns
        """
        patterns = []
        
        try:
            # Weekly patterns
            weekly_patterns = self._identify_weekly_patterns(health_data)
            patterns.extend(weekly_patterns)
            
            # Seasonal patterns (if enough data)
            seasonal_patterns = self._identify_seasonal_patterns(health_data)
            patterns.extend(seasonal_patterns)
            
            # Behavioral patterns
            behavioral_patterns = self._identify_behavioral_patterns(health_data)
            patterns.extend(behavioral_patterns)
            
        except Exception as e:
            logger.error(f"Error identifying patterns: {str(e)}")
        
        return patterns
    
    def detect_improvement_periods(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Detect periods of improvement or decline in health metrics
        
        Args:
            health_data: DataFrame with health metrics
            
        Returns:
            List of improvement/decline periods
        """
        periods = []
        
        try:
            metrics = health_data['metric_type'].unique()
            
            for metric in metrics:
                metric_data = health_data[health_data['metric_type'] == metric].copy()
                
                if len(metric_data) >= 14:  # Need at least 2 weeks of data
                    improvement_periods = self._detect_metric_improvement_periods(metric_data, metric)
                    periods.extend(improvement_periods)
            
        except Exception as e:
            logger.error(f"Error detecting improvement periods: {str(e)}")
        
        return periods
    
    def _analyze_metric_trend(self, metric_data: pd.DataFrame, metric: str) -> Optional[Dict[str, Any]]:
        """Analyze trend for a specific metric"""
        try:
            # Sort by date
            metric_data = metric_data.sort_values('recorded_at')
            
            # Convert dates to numeric for regression
            metric_data['days_since_start'] = (
                metric_data['recorded_at'] - metric_data['recorded_at'].min()
            ).dt.days
            
            # Perform linear regression
            X = metric_data['days_since_start'].values.reshape(-1, 1)
            y = metric_data['value'].values
            
            model = LinearRegression()
            model.fit(X, y)
            
            # Calculate trend statistics
            slope = model.coef_[0]
            r_squared = model.score(X, y)
            
            # Statistical significance test
            _, p_value = stats.pearsonr(metric_data['days_since_start'], metric_data['value'])
            
            # Calculate percentage change
            start_value = metric_data['value'].iloc[0]
            end_value = metric_data['value'].iloc[-1]
            percent_change = ((end_value - start_value) / start_value) * 100 if start_value != 0 else 0
            
            # Determine trend direction and strength
            trend_direction = "improving" if slope > 0 else "declining"
            trend_strength = self._categorize_trend_strength(abs(percent_change))
            
            period_days = metric_data['days_since_start'].max()
            
            return {
                'metric': metric,
                'slope': slope,
                'percent_change': percent_change,
                'r_squared': r_squared,
                'p_value': p_value,
                'confidence': min(1.0, r_squared),
                'direction': trend_direction,
                'strength': trend_strength,
                'period': period_days,
                'start_date': metric_data['recorded_at'].min(),
                'end_date': metric_data['recorded_at'].max(),
                'start_value': start_value,
                'end_value': end_value,
                'recommendations': self._generate_trend_recommendations(metric, trend_direction, percent_change)
            }
            
        except Exception as e:
            logger.error(f"Error analyzing trend for {metric}: {str(e)}")
            return None
    
    def _identify_weekly_patterns(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Identify weekly patterns in health data"""
        patterns = []
        
        try:
            health_data = health_data.copy()
            health_data['day_of_week'] = pd.to_datetime(health_data['recorded_at']).dt.day_name()
            
            metrics = health_data['metric_type'].unique()
            
            for metric in metrics:
                metric_data = health_data[health_data['metric_type'] == metric]
                
                if len(metric_data) >= 14:  # At least 2 weeks of data
                    weekly_avg = metric_data.groupby('day_of_week')['value'].mean()
                    
                    # Find best and worst days
                    best_day = weekly_avg.idxmax()
                    worst_day = weekly_avg.idxmin()
                    
                    # Calculate variation
                    variation = (weekly_avg.max() - weekly_avg.min()) / weekly_avg.mean() * 100
                    
                    if variation > 15:  # Significant weekly variation
                        patterns.append({
                            'type': 'weekly_pattern',
                            'metric': metric,
                            'description': f"Your {metric.replace('_', ' ')} shows a weekly pattern with {best_day} being your best day and {worst_day} your lowest.",
                            'metrics': [metric],
                            'confidence': min(1.0, variation / 50),
                            'best_day': best_day,
                            'worst_day': worst_day,
                            'variation_percent': variation,
                            'weekly_averages': weekly_avg.to_dict(),
                            'recommendations': self._generate_weekly_pattern_recommendations(metric, best_day, worst_day)
                        })
            
        except Exception as e:
            logger.error(f"Error identifying weekly patterns: {str(e)}")
        
        return patterns
    
    def _identify_seasonal_patterns(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Identify seasonal patterns (requires at least 3 months of data)"""
        patterns = []
        
        try:
            # Check if we have enough data for seasonal analysis
            date_range = (health_data['recorded_at'].max() - health_data['recorded_at'].min()).days
            
            if date_range < 90:  # Less than 3 months
                return patterns
            
            health_data = health_data.copy()
            health_data['month'] = pd.to_datetime(health_data['recorded_at']).dt.month
            
            metrics = health_data['metric_type'].unique()
            
            for metric in metrics:
                metric_data = health_data[health_data['metric_type'] == metric]
                
                if len(metric_data) >= 30:  # At least a month of data
                    monthly_avg = metric_data.groupby('month')['value'].mean()
                    
                    if len(monthly_avg) >= 3:  # At least 3 months
                        # Find seasonal trends
                        best_month = monthly_avg.idxmax()
                        worst_month = monthly_avg.idxmin()
                        
                        variation = (monthly_avg.max() - monthly_avg.min()) / monthly_avg.mean() * 100
                        
                        if variation > 20:  # Significant seasonal variation
                            patterns.append({
                                'type': 'seasonal_pattern',
                                'metric': metric,
                                'description': f"Your {metric.replace('_', ' ')} shows seasonal variation with month {best_month} being your best and month {worst_month} your lowest.",
                                'metrics': [metric],
                                'confidence': min(1.0, variation / 100),
                                'best_month': best_month,
                                'worst_month': worst_month,
                                'variation_percent': variation,
                                'monthly_averages': monthly_avg.to_dict(),
                                'recommendations': self._generate_seasonal_recommendations(metric, best_month, worst_month)
                            })
            
        except Exception as e:
            logger.error(f"Error identifying seasonal patterns: {str(e)}")
        
        return patterns
    
    def _identify_behavioral_patterns(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Identify behavioral patterns in health data"""
        patterns = []
        
        try:
            # Look for consistency patterns
            consistency_patterns = self._analyze_consistency_patterns(health_data)
            patterns.extend(consistency_patterns)
            
            # Look for streak patterns
            streak_patterns = self._analyze_streak_patterns(health_data)
            patterns.extend(streak_patterns)
            
        except Exception as e:
            logger.error(f"Error identifying behavioral patterns: {str(e)}")
        
        return patterns
    
    def _analyze_consistency_patterns(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Analyze consistency in health tracking"""
        patterns = []
        
        try:
            # Calculate tracking consistency
            health_data['date'] = pd.to_datetime(health_data['recorded_at']).dt.date
            
            # Count unique tracking days
            total_days = (health_data['date'].max() - health_data['date'].min()).days + 1
            tracking_days = health_data['date'].nunique()
            consistency_rate = tracking_days / total_days * 100
            
            if consistency_rate > 80:
                patterns.append({
                    'type': 'high_consistency',
                    'description': f"You're highly consistent with health tracking, logging data {consistency_rate:.1f}% of days.",
                    'metrics': ['all'],
                    'confidence': consistency_rate / 100,
                    'consistency_rate': consistency_rate,
                    'tracking_days': tracking_days,
                    'total_days': total_days,
                    'recommendations': ["Keep up your excellent tracking consistency!", "Your consistent data helps provide better insights."]
                })
            elif consistency_rate < 50:
                patterns.append({
                    'type': 'low_consistency',
                    'description': f"Your health tracking consistency is {consistency_rate:.1f}%. More regular tracking would provide better insights.",
                    'metrics': ['all'],
                    'confidence': (100 - consistency_rate) / 100,
                    'consistency_rate': consistency_rate,
                    'tracking_days': tracking_days,
                    'total_days': total_days,
                    'recommendations': [
                        "Try setting daily reminders to track your health metrics",
                        "Start with tracking just one metric consistently",
                        "Use automated tracking when possible"
                    ]
                })
            
        except Exception as e:
            logger.error(f"Error analyzing consistency patterns: {str(e)}")
        
        return patterns
    
    def _analyze_streak_patterns(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Analyze streak patterns in health data"""
        patterns = []
        
        try:
            # Look for goal achievement streaks (simplified)
            health_data['date'] = pd.to_datetime(health_data['recorded_at']).dt.date
            
            # Example: Step goal streaks
            steps_data = health_data[health_data['metric_type'] == 'activity_steps']
            if not steps_data.empty:
                daily_steps = steps_data.groupby('date')['value'].max()
                goal_days = daily_steps[daily_steps >= 10000]  # 10k step goal
                
                if len(goal_days) > 0:
                    # Calculate current streak
                    current_streak = self._calculate_current_streak(goal_days.index, daily_steps.index[-1])
                    
                    if current_streak >= 7:
                        patterns.append({
                            'type': 'step_goal_streak',
                            'description': f"You're on a {current_streak}-day streak of reaching your step goal!",
                            'metrics': ['activity_steps'],
                            'confidence': 1.0,
                            'streak_length': current_streak,
                            'goal_achievement_rate': len(goal_days) / len(daily_steps) * 100,
                            'recommendations': [
                                "Keep up your amazing step goal streak!",
                                "Consider gradually increasing your daily step target"
                            ]
                        })
            
        except Exception as e:
            logger.error(f"Error analyzing streak patterns: {str(e)}")
        
        return patterns
    
    def _detect_metric_improvement_periods(self, metric_data: pd.DataFrame, metric: str) -> List[Dict[str, Any]]:
        """Detect periods of improvement or decline for a specific metric"""
        periods = []
        
        try:
            # Sort by date
            metric_data = metric_data.sort_values('recorded_at')
            
            # Use rolling window to detect improvement periods
            window_size = 7  # 7-day windows
            
            if len(metric_data) >= window_size * 2:
                metric_data['rolling_avg'] = metric_data['value'].rolling(window=window_size).mean()
                
                # Find periods where rolling average consistently increases/decreases
                metric_data['trend'] = metric_data['rolling_avg'].diff()
                
                # Identify improvement periods (3+ consecutive positive trends)
                improvement_start = None
                consecutive_improvements = 0
                
                for idx, row in metric_data.iterrows():
                    if pd.notna(row['trend']) and row['trend'] > 0:
                        if improvement_start is None:
                            improvement_start = row['recorded_at']
                        consecutive_improvements += 1
                    else:
                        if consecutive_improvements >= 3:  # At least 3 consecutive improvements
                            periods.append({
                                'type': 'improvement_period',
                                'metric': metric,
                                'start_date': improvement_start,
                                'end_date': metric_data.loc[idx-1, 'recorded_at'] if idx > 0 else row['recorded_at'],
                                'duration_days': consecutive_improvements,
                                'description': f"You had a {consecutive_improvements}-day improvement period in {metric.replace('_', ' ')}",
                                'confidence': min(1.0, consecutive_improvements / 10)
                            })
                        
                        improvement_start = None
                        consecutive_improvements = 0
            
        except Exception as e:
            logger.error(f"Error detecting improvement periods for {metric}: {str(e)}")
        
        return periods
    
    def _categorize_trend_strength(self, percent_change: float) -> str:
        """Categorize the strength of a trend based on percent change"""
        abs_change = abs(percent_change)
        
        if abs_change >= 50:
            return "very strong"
        elif abs_change >= 25:
            return "strong"
        elif abs_change >= 10:
            return "moderate"
        elif abs_change >= 5:
            return "weak"
        else:
            return "minimal"
    
    def _calculate_current_streak(self, goal_dates: pd.Index, last_date) -> int:
        """Calculate current streak of consecutive goal achievements"""
        if len(goal_dates) == 0:
            return 0
        
        # Convert to list and sort
        goal_dates_list = sorted(goal_dates)
        
        # Count backwards from the last date
        streak = 0
        current_date = last_date
        
        for i in range(len(goal_dates_list) - 1, -1, -1):
            if goal_dates_list[i] == current_date:
                streak += 1
                current_date = current_date - timedelta(days=1)
            else:
                break
        
        return streak
    
    def _generate_trend_recommendations(self, metric: str, direction: str, percent_change: float) -> List[str]:
        """Generate recommendations based on trend analysis"""
        recommendations = []
        
        if direction == "improving":
            recommendations.append(f"Great job! Your {metric.replace('_', ' ')} is improving. Keep up the good work!")
            
            if metric == 'activity_steps':
                recommendations.extend([
                    "Consider setting a higher daily step goal",
                    "Try exploring new walking routes to maintain motivation"
                ])
            elif metric == 'sleep_duration':
                recommendations.extend([
                    "Your sleep duration is improving - maintain your current sleep schedule",
                    "Consider tracking sleep quality metrics as well"
                ])
        else:  # declining
            recommendations.append(f"Your {metric.replace('_', ' ')} has been declining. Let's work on improving it.")
            
            if metric == 'activity_steps':
                recommendations.extend([
                    "Try setting smaller, achievable daily step goals",
                    "Consider taking walking breaks throughout the day"
                ])
            elif metric == 'sleep_duration':
                recommendations.extend([
                    "Focus on establishing a consistent bedtime routine",
                    "Consider reducing screen time before bed"
                ])
        
        return recommendations
    
    def _generate_weekly_pattern_recommendations(self, metric: str, best_day: str, worst_day: str) -> List[str]:
        """Generate recommendations based on weekly patterns"""
        recommendations = [
            f"Your {metric.replace('_', ' ')} peaks on {best_day}s - try to replicate what you do differently that day",
            f"Focus on improving your {metric.replace('_', ' ')} on {worst_day}s"
        ]
        
        if metric == 'activity_steps':
            recommendations.append("Consider planning active activities for your typically less active days")
        elif metric == 'sleep_duration':
            recommendations.append("Pay attention to your weekend sleep schedule and try to maintain consistency")
        
        return recommendations
    
    def _generate_seasonal_recommendations(self, metric: str, best_month: int, worst_month: int) -> List[str]:
        """Generate recommendations based on seasonal patterns"""
        month_names = {
            1: "January", 2: "February", 3: "March", 4: "April",
            5: "May", 6: "June", 7: "July", 8: "August",
            9: "September", 10: "October", 11: "November", 12: "December"
        }
        
        recommendations = [
            f"Your {metric.replace('_', ' ')} is typically best in {month_names[best_month]}",
            f"Plan ahead for {month_names[worst_month]} when your {metric.replace('_', ' ')} tends to be lower"
        ]
        
        return recommendations 
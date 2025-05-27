"""
Correlation Analyzer - Statistical Analysis of Health Metric Relationships

This module analyzes correlations between different health metrics to identify
meaningful relationships and provide insights about how different aspects of
health influence each other.
"""

import numpy as np
import pandas as pd
from scipy import stats
from typing import Dict, List, Tuple, Any
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class CorrelationAnalyzer:
    """
    Analyzes correlations between health metrics to identify meaningful relationships
    """
    
    def __init__(self):
        self.min_data_points = 7  # Minimum data points for correlation analysis
        self.significance_threshold = 0.05  # P-value threshold for statistical significance
        
    def find_significant_correlations(
        self, 
        health_data: pd.DataFrame,
        min_correlation: float = 0.3
    ) -> List[Dict[str, Any]]:
        """
        Find statistically significant correlations between health metrics
        
        Args:
            health_data: DataFrame with health metrics
            min_correlation: Minimum correlation strength to report
            
        Returns:
            List of correlation insights
        """
        correlations = []
        
        try:
            # Pivot data to have metrics as columns
            pivot_data = self._prepare_correlation_data(health_data)
            
            if pivot_data.empty or len(pivot_data.columns) < 2:
                return correlations
            
            # Calculate correlations between all metric pairs
            metric_pairs = self._get_metric_pairs(pivot_data.columns)
            
            for metric1, metric2 in metric_pairs:
                correlation_result = self._calculate_correlation(
                    pivot_data, metric1, metric2, min_correlation
                )
                
                if correlation_result:
                    correlations.append(correlation_result)
            
            # Sort by correlation strength
            correlations.sort(key=lambda x: abs(x['strength']), reverse=True)
            
        except Exception as e:
            logger.error(f"Error finding correlations: {str(e)}")
        
        return correlations
    
    def analyze_metric_relationships(
        self, 
        health_data: pd.DataFrame,
        target_metric: str
    ) -> Dict[str, Any]:
        """
        Analyze how other metrics relate to a specific target metric
        
        Args:
            health_data: DataFrame with health metrics
            target_metric: The metric to analyze relationships for
            
        Returns:
            Dictionary with relationship analysis
        """
        try:
            pivot_data = self._prepare_correlation_data(health_data)
            
            if target_metric not in pivot_data.columns:
                return {}
            
            relationships = {}
            target_data = pivot_data[target_metric].dropna()
            
            for metric in pivot_data.columns:
                if metric != target_metric:
                    metric_data = pivot_data[metric].dropna()
                    
                    # Find common data points
                    common_indices = target_data.index.intersection(metric_data.index)
                    
                    if len(common_indices) >= self.min_data_points:
                        target_values = target_data[common_indices]
                        metric_values = metric_data[common_indices]
                        
                        # Calculate correlation
                        correlation, p_value = stats.pearsonr(target_values, metric_values)
                        
                        if abs(correlation) > 0.2 and p_value < self.significance_threshold:
                            relationships[metric] = {
                                'correlation': correlation,
                                'p_value': p_value,
                                'strength': self._interpret_correlation_strength(correlation),
                                'direction': 'positive' if correlation > 0 else 'negative',
                                'interpretation': self._interpret_relationship(target_metric, metric, correlation)
                            }
            
            return {
                'target_metric': target_metric,
                'relationships': relationships,
                'strongest_positive': max(
                    [(k, v) for k, v in relationships.items() if v['correlation'] > 0],
                    key=lambda x: x[1]['correlation'],
                    default=(None, None)
                ),
                'strongest_negative': min(
                    [(k, v) for k, v in relationships.items() if v['correlation'] < 0],
                    key=lambda x: x[1]['correlation'],
                    default=(None, None)
                )
            }
            
        except Exception as e:
            logger.error(f"Error analyzing relationships for {target_metric}: {str(e)}")
            return {}
    
    def _prepare_correlation_data(self, health_data: pd.DataFrame) -> pd.DataFrame:
        """Prepare data for correlation analysis by pivoting metrics"""
        try:
            # Convert recorded_at to date for daily aggregation
            health_data = health_data.copy()
            health_data['date'] = pd.to_datetime(health_data['recorded_at']).dt.date
            
            # Aggregate by date and metric type (take mean for multiple readings per day)
            daily_data = health_data.groupby(['date', 'metric_type'])['value'].mean().reset_index()
            
            # Pivot to have metrics as columns
            pivot_data = daily_data.pivot(index='date', columns='metric_type', values='value')
            
            # Only include metrics with sufficient data
            sufficient_data_metrics = []
            for metric in pivot_data.columns:
                if pivot_data[metric].count() >= self.min_data_points:
                    sufficient_data_metrics.append(metric)
            
            return pivot_data[sufficient_data_metrics]
            
        except Exception as e:
            logger.error(f"Error preparing correlation data: {str(e)}")
            return pd.DataFrame()
    
    def _get_metric_pairs(self, metrics: List[str]) -> List[Tuple[str, str]]:
        """Get all unique pairs of metrics for correlation analysis"""
        pairs = []
        for i, metric1 in enumerate(metrics):
            for metric2 in metrics[i+1:]:
                pairs.append((metric1, metric2))
        return pairs
    
    def _calculate_correlation(
        self, 
        pivot_data: pd.DataFrame, 
        metric1: str, 
        metric2: str,
        min_correlation: float
    ) -> Dict[str, Any]:
        """Calculate correlation between two metrics"""
        try:
            # Get data for both metrics
            data1 = pivot_data[metric1].dropna()
            data2 = pivot_data[metric2].dropna()
            
            # Find common data points
            common_indices = data1.index.intersection(data2.index)
            
            if len(common_indices) < self.min_data_points:
                return None
            
            values1 = data1[common_indices]
            values2 = data2[common_indices]
            
            # Calculate Pearson correlation
            correlation, p_value = stats.pearsonr(values1, values2)
            
            # Check if correlation meets minimum threshold and is significant
            if abs(correlation) < min_correlation or p_value >= self.significance_threshold:
                return None
            
            return {
                'metric1': metric1,
                'metric2': metric2,
                'strength': correlation,
                'p_value': p_value,
                'data_points': len(common_indices),
                'strength_category': self._interpret_correlation_strength(correlation),
                'direction': 'positive' if correlation > 0 else 'negative',
                'interpretation': self._interpret_relationship(metric1, metric2, correlation),
                'recommendations': self._generate_correlation_recommendations(metric1, metric2, correlation)
            }
            
        except Exception as e:
            logger.error(f"Error calculating correlation between {metric1} and {metric2}: {str(e)}")
            return None
    
    def _interpret_correlation_strength(self, correlation: float) -> str:
        """Interpret the strength of a correlation coefficient"""
        abs_corr = abs(correlation)
        
        if abs_corr >= 0.8:
            return "very strong"
        elif abs_corr >= 0.6:
            return "strong"
        elif abs_corr >= 0.4:
            return "moderate"
        elif abs_corr >= 0.2:
            return "weak"
        else:
            return "very weak"
    
    def _interpret_relationship(self, metric1: str, metric2: str, correlation: float) -> str:
        """Generate human-readable interpretation of the relationship"""
        direction = "positively" if correlation > 0 else "negatively"
        strength = self._interpret_correlation_strength(correlation)
        
        # Create more specific interpretations based on metric types
        interpretations = {
            ('activity_steps', 'sleep_duration'): {
                'positive': "More active days tend to lead to better sleep duration.",
                'negative': "Higher activity levels may be associated with shorter sleep duration."
            },
            ('sleep_duration', 'heart_rate_resting'): {
                'positive': "Longer sleep duration is associated with higher resting heart rate.",
                'negative': "Better sleep duration tends to correlate with lower resting heart rate."
            },
            ('activity_steps', 'heart_rate_resting'): {
                'positive': "More daily steps are associated with higher resting heart rate.",
                'negative': "Higher daily activity is linked to lower resting heart rate, indicating better fitness."
            },
            ('nutrition_calories', 'activity_steps'): {
                'positive': "Higher calorie intake days tend to coincide with more active days.",
                'negative': "Higher calorie intake is associated with lower activity levels."
            }
        }
        
        # Try to find specific interpretation
        key = (metric1, metric2)
        reverse_key = (metric2, metric1)
        
        if key in interpretations:
            return interpretations[key]['positive' if correlation > 0 else 'negative']
        elif reverse_key in interpretations:
            return interpretations[reverse_key]['positive' if correlation > 0 else 'negative']
        else:
            return f"These metrics show a {strength} {direction} relationship."
    
    def _generate_correlation_recommendations(
        self, 
        metric1: str, 
        metric2: str, 
        correlation: float
    ) -> List[str]:
        """Generate actionable recommendations based on correlations"""
        recommendations = []
        
        # Specific recommendations based on metric pairs
        if correlation > 0.5:  # Strong positive correlation
            if 'activity_steps' in [metric1, metric2] and 'sleep_duration' in [metric1, metric2]:
                recommendations.extend([
                    "Maintain consistent daily activity to support healthy sleep patterns",
                    "Consider timing your workouts earlier in the day for better sleep"
                ])
            elif 'sleep_duration' in [metric1, metric2] and 'heart_rate_resting' in [metric1, metric2]:
                recommendations.extend([
                    "Focus on sleep quality and duration to support heart health",
                    "Establish a consistent sleep schedule"
                ])
            elif 'nutrition_calories' in [metric1, metric2] and 'activity_steps' in [metric1, metric2]:
                recommendations.extend([
                    "Balance your calorie intake with your activity level",
                    "Consider increasing activity on higher calorie days"
                ])
        
        elif correlation < -0.5:  # Strong negative correlation
            if 'activity_steps' in [metric1, metric2] and 'heart_rate_resting' in [metric1, metric2]:
                recommendations.extend([
                    "Continue your active lifestyle to maintain low resting heart rate",
                    "Regular cardio exercise helps improve heart efficiency"
                ])
        
        # General recommendations
        if abs(correlation) > 0.6:
            recommendations.append(f"Monitor both {metric1.replace('_', ' ')} and {metric2.replace('_', ' ')} together for better health insights")
        
        return recommendations 
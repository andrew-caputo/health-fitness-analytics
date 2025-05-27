"""
Recommendation Engine - Personalized Health Recommendations

This module generates personalized health recommendations based on user data,
patterns, goals, and best practices. It provides actionable insights to help
users improve their health and wellness.
"""

import numpy as np
import pandas as pd
from typing import Dict, List, Any, Optional
import logging
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


class RecommendationEngine:
    """
    Generates personalized health recommendations based on user data and patterns
    """
    
    def __init__(self):
        self.min_data_points = 7
        self.recommendation_categories = [
            'activity', 'sleep', 'nutrition', 'heart_health', 'weight_management', 'general'
        ]
        
    def generate_recommendations(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """
        Generate comprehensive personalized recommendations
        
        Args:
            health_data: DataFrame with health metrics
            
        Returns:
            List of personalized recommendations
        """
        recommendations = []
        
        try:
            # Activity recommendations
            activity_recs = self._generate_activity_recommendations(health_data)
            recommendations.extend(activity_recs)
            
            # Sleep recommendations
            sleep_recs = self._generate_sleep_recommendations(health_data)
            recommendations.extend(sleep_recs)
            
            # Nutrition recommendations
            nutrition_recs = self._generate_nutrition_recommendations(health_data)
            recommendations.extend(nutrition_recs)
            
            # Heart health recommendations
            heart_recs = self._generate_heart_health_recommendations(health_data)
            recommendations.extend(heart_recs)
            
            # Weight management recommendations
            weight_recs = self._generate_weight_management_recommendations(health_data)
            recommendations.extend(weight_recs)
            
            # General wellness recommendations
            general_recs = self._generate_general_recommendations(health_data)
            recommendations.extend(general_recs)
            
            # Sort by priority and confidence
            recommendations.sort(key=lambda x: (x['priority'], -x['confidence']), reverse=True)
            
        except Exception as e:
            logger.error(f"Error generating recommendations: {str(e)}")
        
        return recommendations
    
    def generate_goal_recommendations(
        self, 
        health_data: pd.DataFrame, 
        user_goals: Dict[str, Any]
    ) -> List[Dict[str, Any]]:
        """
        Generate recommendations based on specific user goals
        
        Args:
            health_data: DataFrame with health metrics
            user_goals: Dictionary of user goals and targets
            
        Returns:
            List of goal-specific recommendations
        """
        recommendations = []
        
        try:
            for goal_type, goal_value in user_goals.items():
                goal_recs = self._generate_goal_specific_recommendations(
                    health_data, goal_type, goal_value
                )
                recommendations.extend(goal_recs)
                
        except Exception as e:
            logger.error(f"Error generating goal recommendations: {str(e)}")
        
        return recommendations
    
    def _generate_activity_recommendations(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Generate activity-related recommendations"""
        recommendations = []
        
        try:
            steps_data = health_data[health_data['metric_type'] == 'activity_steps']
            
            if not steps_data.empty:
                recent_avg_steps = steps_data.nlargest(7, 'recorded_at')['value'].mean()
                overall_avg_steps = steps_data['value'].mean()
                
                # Step recommendations
                if recent_avg_steps < 5000:
                    recommendations.append({
                        'category': 'activity',
                        'title': 'Increase Daily Movement',
                        'description': f'Your recent average of {recent_avg_steps:.0f} steps is below recommended levels.',
                        'metrics': ['activity_steps'],
                        'confidence': 0.9,
                        'priority': 'high',
                        'actions': [
                            'Start with a goal of 6,000 steps per day',
                            'Take a 10-minute walk after each meal',
                            'Use stairs instead of elevators when possible',
                            'Park farther away or get off transit one stop early'
                        ],
                        'expected_benefit': 'Improved cardiovascular health and energy levels',
                        'timeframe': '2-4 weeks'
                    })
                elif recent_avg_steps < 8000:
                    recommendations.append({
                        'category': 'activity',
                        'title': 'Boost Your Step Count',
                        'description': f'You\'re averaging {recent_avg_steps:.0f} steps. Let\'s aim higher!',
                        'metrics': ['activity_steps'],
                        'confidence': 0.8,
                        'priority': 'medium',
                        'actions': [
                            'Set a goal of 10,000 steps per day',
                            'Take walking meetings when possible',
                            'Explore new walking routes in your neighborhood',
                            'Consider a lunchtime walk routine'
                        ],
                        'expected_benefit': 'Enhanced fitness and weight management',
                        'timeframe': '3-6 weeks'
                    })
                elif recent_avg_steps > 12000:
                    recommendations.append({
                        'category': 'activity',
                        'title': 'Maintain Your Excellent Activity Level',
                        'description': f'Great job! You\'re averaging {recent_avg_steps:.0f} steps per day.',
                        'metrics': ['activity_steps'],
                        'confidence': 0.9,
                        'priority': 'low',
                        'actions': [
                            'Continue your current activity routine',
                            'Consider adding strength training 2-3 times per week',
                            'Try new activities to prevent boredom',
                            'Focus on recovery and rest days'
                        ],
                        'expected_benefit': 'Sustained fitness and long-term health',
                        'timeframe': 'Ongoing'
                    })
                
                # Consistency recommendations
                if len(steps_data) >= 14:
                    step_consistency = 1 - (steps_data['value'].std() / steps_data['value'].mean())
                    
                    if step_consistency < 0.7:
                        recommendations.append({
                            'category': 'activity',
                            'title': 'Improve Activity Consistency',
                            'description': 'Your daily activity varies significantly. Consistency is key for health benefits.',
                            'metrics': ['activity_steps'],
                            'confidence': 0.8,
                            'priority': 'medium',
                            'actions': [
                                'Set a minimum daily step goal',
                                'Schedule regular activity times',
                                'Track your activity throughout the day',
                                'Plan indoor activities for bad weather days'
                            ],
                            'expected_benefit': 'More stable energy levels and better habit formation',
                            'timeframe': '4-8 weeks'
                        })
            
        except Exception as e:
            logger.error(f"Error generating activity recommendations: {str(e)}")
        
        return recommendations
    
    def _generate_sleep_recommendations(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Generate sleep-related recommendations"""
        recommendations = []
        
        try:
            sleep_data = health_data[health_data['metric_type'] == 'sleep_duration']
            
            if not sleep_data.empty:
                recent_avg_sleep = sleep_data.nlargest(7, 'recorded_at')['value'].mean()
                
                # Sleep duration recommendations
                if recent_avg_sleep < 7:
                    recommendations.append({
                        'category': 'sleep',
                        'title': 'Increase Sleep Duration',
                        'description': f'You\'re averaging {recent_avg_sleep:.1f} hours of sleep, below the recommended 7-9 hours.',
                        'metrics': ['sleep_duration'],
                        'confidence': 0.9,
                        'priority': 'high',
                        'actions': [
                            'Set a consistent bedtime 30 minutes earlier',
                            'Create a relaxing bedtime routine',
                            'Limit screen time 1 hour before bed',
                            'Keep your bedroom cool, dark, and quiet'
                        ],
                        'expected_benefit': 'Better mood, energy, and cognitive function',
                        'timeframe': '1-2 weeks'
                    })
                elif recent_avg_sleep > 9.5:
                    recommendations.append({
                        'category': 'sleep',
                        'title': 'Optimize Sleep Quality',
                        'description': f'You\'re sleeping {recent_avg_sleep:.1f} hours. Focus on quality over quantity.',
                        'metrics': ['sleep_duration'],
                        'confidence': 0.7,
                        'priority': 'medium',
                        'actions': [
                            'Evaluate sleep quality, not just duration',
                            'Consider if you\'re getting deep, restorative sleep',
                            'Maintain consistent sleep and wake times',
                            'Consult a healthcare provider if you feel tired despite long sleep'
                        ],
                        'expected_benefit': 'More efficient, restorative sleep',
                        'timeframe': '2-4 weeks'
                    })
                else:
                    recommendations.append({
                        'category': 'sleep',
                        'title': 'Maintain Good Sleep Habits',
                        'description': f'Your sleep duration of {recent_avg_sleep:.1f} hours is in the healthy range.',
                        'metrics': ['sleep_duration'],
                        'confidence': 0.8,
                        'priority': 'low',
                        'actions': [
                            'Continue your current sleep schedule',
                            'Focus on sleep consistency',
                            'Monitor sleep quality indicators',
                            'Adjust routine if life changes affect sleep'
                        ],
                        'expected_benefit': 'Sustained energy and health',
                        'timeframe': 'Ongoing'
                    })
                
                # Sleep consistency recommendations
                if len(sleep_data) >= 14:
                    sleep_consistency = 1 - (sleep_data['value'].std() / sleep_data['value'].mean())
                    
                    if sleep_consistency < 0.8:
                        recommendations.append({
                            'category': 'sleep',
                            'title': 'Improve Sleep Consistency',
                            'description': 'Your sleep duration varies significantly night to night.',
                            'metrics': ['sleep_duration'],
                            'confidence': 0.8,
                            'priority': 'medium',
                            'actions': [
                                'Set the same bedtime and wake time every day',
                                'Avoid "catching up" on sleep during weekends',
                                'Create a consistent pre-sleep routine',
                                'Limit caffeine and alcohol, especially in the evening'
                            ],
                            'expected_benefit': 'Better sleep quality and daytime alertness',
                            'timeframe': '3-4 weeks'
                        })
            
        except Exception as e:
            logger.error(f"Error generating sleep recommendations: {str(e)}")
        
        return recommendations
    
    def _generate_nutrition_recommendations(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Generate nutrition-related recommendations"""
        recommendations = []
        
        try:
            calories_data = health_data[health_data['metric_type'] == 'nutrition_calories']
            protein_data = health_data[health_data['metric_type'] == 'nutrition_protein']
            
            # Calorie tracking recommendations
            if calories_data.empty:
                recommendations.append({
                    'category': 'nutrition',
                    'title': 'Start Tracking Your Nutrition',
                    'description': 'Nutrition tracking helps you understand your eating patterns and make informed choices.',
                    'metrics': ['nutrition_calories'],
                    'confidence': 0.9,
                    'priority': 'medium',
                    'actions': [
                        'Begin logging your meals and snacks',
                        'Use a nutrition tracking app like MyFitnessPal',
                        'Start with tracking just calories, then add macronutrients',
                        'Focus on awareness rather than restriction initially'
                    ],
                    'expected_benefit': 'Better understanding of eating habits and improved nutrition choices',
                    'timeframe': '1-2 weeks to establish habit'
                })
            else:
                recent_avg_calories = calories_data.nlargest(7, 'recorded_at')['value'].mean()
                
                # Basic calorie recommendations (simplified)
                if recent_avg_calories < 1200:
                    recommendations.append({
                        'category': 'nutrition',
                        'title': 'Ensure Adequate Calorie Intake',
                        'description': f'Your recent average of {recent_avg_calories:.0f} calories may be too low.',
                        'metrics': ['nutrition_calories'],
                        'confidence': 0.8,
                        'priority': 'high',
                        'actions': [
                            'Consult with a healthcare provider or nutritionist',
                            'Focus on nutrient-dense foods',
                            'Ensure you\'re eating regular meals',
                            'Consider if tracking is accurate and complete'
                        ],
                        'expected_benefit': 'Better energy levels and metabolic health',
                        'timeframe': 'Immediate consultation recommended'
                    })
                elif recent_avg_calories > 3000:
                    recommendations.append({
                        'category': 'nutrition',
                        'title': 'Review Calorie Intake',
                        'description': f'Your recent average of {recent_avg_calories:.0f} calories is quite high.',
                        'metrics': ['nutrition_calories'],
                        'confidence': 0.7,
                        'priority': 'medium',
                        'actions': [
                            'Review portion sizes and meal frequency',
                            'Focus on whole, unprocessed foods',
                            'Consider consulting with a nutritionist',
                            'Ensure tracking accuracy'
                        ],
                        'expected_benefit': 'Better weight management and energy balance',
                        'timeframe': '2-4 weeks'
                    })
            
            # Protein recommendations
            if not protein_data.empty and not calories_data.empty:
                recent_protein = protein_data.nlargest(7, 'recorded_at')['value'].mean()
                recent_calories = calories_data.nlargest(7, 'recorded_at')['value'].mean()
                protein_percentage = (recent_protein * 4) / recent_calories * 100
                
                if protein_percentage < 15:
                    recommendations.append({
                        'category': 'nutrition',
                        'title': 'Increase Protein Intake',
                        'description': f'Your protein intake is {protein_percentage:.1f}% of calories. Aim for 15-25%.',
                        'metrics': ['nutrition_protein'],
                        'confidence': 0.8,
                        'priority': 'medium',
                        'actions': [
                            'Include protein in every meal',
                            'Add lean meats, fish, eggs, or plant proteins',
                            'Consider protein-rich snacks like Greek yogurt or nuts',
                            'Aim for 0.8-1.2g protein per kg body weight'
                        ],
                        'expected_benefit': 'Better muscle maintenance and satiety',
                        'timeframe': '2-3 weeks'
                    })
            
        except Exception as e:
            logger.error(f"Error generating nutrition recommendations: {str(e)}")
        
        return recommendations
    
    def _generate_heart_health_recommendations(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Generate heart health recommendations"""
        recommendations = []
        
        try:
            resting_hr_data = health_data[health_data['metric_type'] == 'heart_rate_resting']
            
            if not resting_hr_data.empty:
                recent_resting_hr = resting_hr_data.nlargest(7, 'recorded_at')['value'].mean()
                
                if recent_resting_hr > 80:
                    recommendations.append({
                        'category': 'heart_health',
                        'title': 'Improve Cardiovascular Fitness',
                        'description': f'Your resting heart rate of {recent_resting_hr:.0f} bpm could be improved.',
                        'metrics': ['heart_rate_resting'],
                        'confidence': 0.8,
                        'priority': 'medium',
                        'actions': [
                            'Incorporate regular cardio exercise',
                            'Start with 150 minutes of moderate activity per week',
                            'Try activities like brisk walking, cycling, or swimming',
                            'Gradually increase intensity as fitness improves'
                        ],
                        'expected_benefit': 'Lower resting heart rate and improved cardiovascular health',
                        'timeframe': '6-12 weeks'
                    })
                elif recent_resting_hr < 60:
                    recommendations.append({
                        'category': 'heart_health',
                        'title': 'Excellent Cardiovascular Fitness',
                        'description': f'Your resting heart rate of {recent_resting_hr:.0f} bpm indicates good fitness.',
                        'metrics': ['heart_rate_resting'],
                        'confidence': 0.9,
                        'priority': 'low',
                        'actions': [
                            'Maintain your current fitness routine',
                            'Consider heart rate variability tracking',
                            'Focus on recovery and stress management',
                            'Monitor for any unusual changes'
                        ],
                        'expected_benefit': 'Sustained cardiovascular health',
                        'timeframe': 'Ongoing'
                    })
            
        except Exception as e:
            logger.error(f"Error generating heart health recommendations: {str(e)}")
        
        return recommendations
    
    def _generate_weight_management_recommendations(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Generate weight management recommendations"""
        recommendations = []
        
        try:
            weight_data = health_data[health_data['metric_type'] == 'body_weight']
            
            if len(weight_data) >= 14:  # Need at least 2 weeks of data
                weight_data = weight_data.sort_values('recorded_at')
                recent_weights = weight_data.tail(14)
                
                # Calculate trend
                weight_change = recent_weights['value'].iloc[-1] - recent_weights['value'].iloc[0]
                weekly_change = weight_change / 2  # 2 weeks to weekly
                
                if abs(weekly_change) > 2:  # More than 2 lbs per week
                    direction = "gaining" if weight_change > 0 else "losing"
                    recommendations.append({
                        'category': 'weight_management',
                        'title': f'Rapid Weight {direction.title()}',
                        'description': f'You\'re {direction} weight at {abs(weekly_change):.1f} lbs per week.',
                        'metrics': ['body_weight'],
                        'confidence': 0.8,
                        'priority': 'high',
                        'actions': [
                            'Consult with a healthcare provider',
                            'Review recent diet and exercise changes',
                            'Ensure consistent weighing conditions',
                            'Consider if medications or health conditions are factors'
                        ],
                        'expected_benefit': 'Healthier, more sustainable weight management',
                        'timeframe': 'Immediate consultation recommended'
                    })
                elif 0.5 <= abs(weekly_change) <= 2:  # Healthy rate
                    direction = "loss" if weight_change < 0 else "gain"
                    recommendations.append({
                        'category': 'weight_management',
                        'title': f'Healthy Weight {direction.title()}',
                        'description': f'Your weight {direction} of {abs(weekly_change):.1f} lbs/week is in a healthy range.',
                        'metrics': ['body_weight'],
                        'confidence': 0.9,
                        'priority': 'low',
                        'actions': [
                            'Continue your current approach',
                            'Monitor progress consistently',
                            'Focus on sustainable habits',
                            'Celebrate your progress!'
                        ],
                        'expected_benefit': 'Sustainable weight management',
                        'timeframe': 'Ongoing'
                    })
            
        except Exception as e:
            logger.error(f"Error generating weight management recommendations: {str(e)}")
        
        return recommendations
    
    def _generate_general_recommendations(self, health_data: pd.DataFrame) -> List[Dict[str, Any]]:
        """Generate general wellness recommendations"""
        recommendations = []
        
        try:
            # Data tracking consistency
            health_data['date'] = pd.to_datetime(health_data['recorded_at']).dt.date
            total_days = (health_data['date'].max() - health_data['date'].min()).days + 1
            tracking_days = health_data['date'].nunique()
            consistency_rate = tracking_days / total_days * 100
            
            if consistency_rate < 70:
                recommendations.append({
                    'category': 'general',
                    'title': 'Improve Health Tracking Consistency',
                    'description': f'You\'re tracking health data {consistency_rate:.1f}% of days.',
                    'metrics': ['all'],
                    'confidence': 0.9,
                    'priority': 'medium',
                    'actions': [
                        'Set daily reminders to log health data',
                        'Use automated tracking when possible',
                        'Start with tracking just one metric consistently',
                        'Review and sync your devices regularly'
                    ],
                    'expected_benefit': 'Better insights and more personalized recommendations',
                    'timeframe': '2-4 weeks'
                })
            
            # Holistic health recommendation
            recommendations.append({
                'category': 'general',
                'title': 'Focus on Overall Wellness',
                'description': 'Health is multifaceted. Balance activity, sleep, nutrition, and stress management.',
                'metrics': ['all'],
                'confidence': 0.8,
                'priority': 'low',
                'actions': [
                    'Aim for progress in all health areas, not perfection',
                    'Listen to your body and adjust goals as needed',
                    'Consider stress management techniques like meditation',
                    'Stay hydrated and spend time outdoors when possible'
                ],
                'expected_benefit': 'Improved overall health and well-being',
                'timeframe': 'Ongoing lifestyle approach'
            })
            
        except Exception as e:
            logger.error(f"Error generating general recommendations: {str(e)}")
        
        return recommendations
    
    def _generate_goal_specific_recommendations(
        self, 
        health_data: pd.DataFrame, 
        goal_type: str, 
        goal_value: Any
    ) -> List[Dict[str, Any]]:
        """Generate recommendations for specific user goals"""
        recommendations = []
        
        try:
            if goal_type == 'daily_steps':
                steps_data = health_data[health_data['metric_type'] == 'activity_steps']
                if not steps_data.empty:
                    recent_avg = steps_data.nlargest(7, 'recorded_at')['value'].mean()
                    gap = goal_value - recent_avg
                    
                    if gap > 0:
                        recommendations.append({
                            'category': 'activity',
                            'title': f'Reach Your {goal_value:,} Step Goal',
                            'description': f'You need {gap:.0f} more steps daily to reach your goal.',
                            'metrics': ['activity_steps'],
                            'confidence': 0.9,
                            'priority': 'high',
                            'actions': [
                                f'Add {gap//3:.0f} steps to morning, afternoon, and evening',
                                'Take a 10-minute walk (≈1,000 steps) after each meal',
                                'Use a step counter app to track progress throughout the day',
                                'Find opportunities to walk during your daily routine'
                            ],
                            'expected_benefit': f'Achievement of your {goal_value:,} daily step goal',
                            'timeframe': '2-3 weeks'
                        })
            
            elif goal_type == 'target_weight':
                weight_data = health_data[health_data['metric_type'] == 'body_weight']
                if not weight_data.empty:
                    current_weight = weight_data.nlargest(1, 'recorded_at')['value'].iloc[0]
                    weight_diff = current_weight - goal_value
                    
                    if abs(weight_diff) > 2:  # Significant difference
                        direction = "lose" if weight_diff > 0 else "gain"
                        recommendations.append({
                            'category': 'weight_management',
                            'title': f'Work Toward Your Weight Goal',
                            'description': f'You need to {direction} {abs(weight_diff):.1f} lbs to reach your goal.',
                            'metrics': ['body_weight'],
                            'confidence': 0.8,
                            'priority': 'high',
                            'actions': [
                                f'Aim for 1-2 lbs {direction} per week for healthy progress',
                                'Focus on sustainable diet and exercise changes',
                                'Track your food intake and physical activity',
                                'Consider consulting with a nutritionist or trainer'
                            ],
                            'expected_benefit': f'Achievement of your {goal_value} lb weight goal',
                            'timeframe': f'{abs(weight_diff)//1.5:.0f}-{abs(weight_diff):.0f} weeks'
                        })
            
        except Exception as e:
            logger.error(f"Error generating goal-specific recommendations: {str(e)}")
        
        return recommendations 
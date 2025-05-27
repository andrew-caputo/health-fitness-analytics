"""
Goal Optimization Engine

This module provides AI-powered goal recommendations and optimization based on user health patterns,
historical data, and behavioral insights. It includes dynamic goal adjustment algorithms and
multi-metric coordination to ensure balanced health improvement.
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass
from enum import Enum
import numpy as np
import pandas as pd
from sqlalchemy.orm import Session

from ..core.database import get_db
from ..core.models import User, HealthData, UserPreferences
from .health_insights_engine import HealthInsightsEngine
from .pattern_recognition import PatternRecognizer
from .correlation_analyzer import CorrelationAnalyzer

logger = logging.getLogger(__name__)

class GoalCategory(Enum):
    """Health goal categories"""
    ACTIVITY = "activity"
    SLEEP = "sleep"
    NUTRITION = "nutrition"
    BODY_COMPOSITION = "body_composition"
    HEART_HEALTH = "heart_health"
    WELLNESS = "wellness"

class GoalDifficulty(Enum):
    """Goal difficulty levels"""
    EASY = "easy"
    MODERATE = "moderate"
    CHALLENGING = "challenging"
    AMBITIOUS = "ambitious"

class GoalType(Enum):
    """Types of health goals"""
    INCREASE = "increase"
    DECREASE = "decrease"
    MAINTAIN = "maintain"
    ACHIEVE = "achieve"

@dataclass
class GoalRecommendation:
    """Represents an AI-generated goal recommendation"""
    id: str
    category: GoalCategory
    goal_type: GoalType
    title: str
    description: str
    target_value: float
    current_value: float
    unit: str
    difficulty: GoalDifficulty
    timeline_days: int
    confidence_score: float
    reasoning: str
    expected_benefits: List[str]
    success_probability: float
    required_actions: List[str]
    related_metrics: List[str]
    adjustment_triggers: List[str]

@dataclass
class GoalAdjustment:
    """Represents a goal adjustment recommendation"""
    goal_id: str
    adjustment_type: str
    new_target: float
    reasoning: str
    confidence: float
    expected_impact: str

@dataclass
class GoalCoordination:
    """Represents coordination between multiple goals"""
    primary_goal_id: str
    related_goal_ids: List[str]
    coordination_type: str
    impact_description: str
    optimization_suggestions: List[str]

class GoalOptimizer:
    """
    AI-powered goal optimization engine that provides personalized health goal recommendations,
    dynamic adjustments, and multi-metric coordination.
    """
    
    def __init__(self):
        self.insights_engine = HealthInsightsEngine()
        self.pattern_recognizer = PatternRecognizer()
        self.correlation_analyzer = CorrelationAnalyzer()
        
        # Goal templates and thresholds
        self.goal_templates = self._initialize_goal_templates()
        self.difficulty_multipliers = {
            GoalDifficulty.EASY: 0.7,
            GoalDifficulty.MODERATE: 1.0,
            GoalDifficulty.CHALLENGING: 1.3,
            GoalDifficulty.AMBITIOUS: 1.6
        }
        
    def _initialize_goal_templates(self) -> Dict[str, Dict]:
        """Initialize goal templates with default parameters"""
        return {
            "daily_steps": {
                "category": GoalCategory.ACTIVITY,
                "goal_type": GoalType.INCREASE,
                "unit": "steps",
                "baseline_target": 8000,
                "min_increase": 500,
                "max_increase": 3000,
                "timeline_range": (14, 90),
                "benefits": ["Improved cardiovascular health", "Better mood", "Weight management"]
            },
            "sleep_duration": {
                "category": GoalCategory.SLEEP,
                "goal_type": GoalType.ACHIEVE,
                "unit": "hours",
                "baseline_target": 7.5,
                "min_target": 7.0,
                "max_target": 9.0,
                "timeline_range": (21, 60),
                "benefits": ["Better recovery", "Improved cognitive function", "Enhanced immune system"]
            },
            "water_intake": {
                "category": GoalCategory.NUTRITION,
                "goal_type": GoalType.INCREASE,
                "unit": "liters",
                "baseline_target": 2.5,
                "min_increase": 0.2,
                "max_increase": 1.0,
                "timeline_range": (7, 30),
                "benefits": ["Better hydration", "Improved skin health", "Enhanced metabolism"]
            },
            "weight_loss": {
                "category": GoalCategory.BODY_COMPOSITION,
                "goal_type": GoalType.DECREASE,
                "unit": "kg",
                "baseline_target": 0.5,
                "min_target": 0.25,
                "max_target": 1.0,
                "timeline_range": (30, 180),
                "benefits": ["Improved health markers", "Better mobility", "Increased confidence"]
            },
            "resting_heart_rate": {
                "category": GoalCategory.HEART_HEALTH,
                "goal_type": GoalType.DECREASE,
                "unit": "bpm",
                "baseline_target": 5,
                "min_target": 2,
                "max_target": 10,
                "timeline_range": (60, 120),
                "benefits": ["Better cardiovascular fitness", "Improved recovery", "Lower health risks"]
            }
        }
    
    async def generate_goal_recommendations(
        self,
        user_id: int,
        db: Session,
        max_goals: int = 5,
        difficulty_preference: Optional[GoalDifficulty] = None
    ) -> List[GoalRecommendation]:
        """
        Generate personalized goal recommendations based on user health patterns and data.
        
        Args:
            user_id: User identifier
            db: Database session
            max_goals: Maximum number of goals to recommend
            difficulty_preference: Preferred difficulty level
            
        Returns:
            List of goal recommendations
        """
        try:
            logger.info(f"Generating goal recommendations for user {user_id}")
            
            # Get user data and patterns
            user_data = await self._get_user_health_data(user_id, db)
            if not user_data:
                return []
            
            health_patterns = await self.pattern_recognizer.analyze_patterns(user_data)
            correlations = await self.correlation_analyzer.analyze_correlations(user_data)
            current_metrics = self._calculate_current_metrics(user_data)
            
            # Generate recommendations for each goal type
            recommendations = []
            
            for goal_key, template in self.goal_templates.items():
                try:
                    recommendation = await self._generate_single_goal_recommendation(
                        goal_key, template, current_metrics, health_patterns, 
                        correlations, difficulty_preference
                    )
                    if recommendation:
                        recommendations.append(recommendation)
                except Exception as e:
                    logger.error(f"Error generating recommendation for {goal_key}: {e}")
                    continue
            
            # Rank and filter recommendations
            ranked_recommendations = self._rank_recommendations(recommendations, health_patterns)
            
            # Ensure goal coordination
            coordinated_recommendations = self._coordinate_goals(ranked_recommendations[:max_goals])
            
            logger.info(f"Generated {len(coordinated_recommendations)} goal recommendations")
            return coordinated_recommendations
            
        except Exception as e:
            logger.error(f"Error generating goal recommendations: {e}")
            return []
    
    async def _generate_single_goal_recommendation(
        self,
        goal_key: str,
        template: Dict,
        current_metrics: Dict,
        health_patterns: Dict,
        correlations: Dict,
        difficulty_preference: Optional[GoalDifficulty]
    ) -> Optional[GoalRecommendation]:
        """Generate a single goal recommendation"""
        
        # Check if we have relevant data for this goal
        metric_key = self._get_metric_key_for_goal(goal_key)
        if metric_key not in current_metrics:
            return None
        
        current_value = current_metrics[metric_key]
        if current_value is None:
            return None
        
        # Determine difficulty level
        difficulty = difficulty_preference or self._determine_optimal_difficulty(
            goal_key, current_metrics, health_patterns
        )
        
        # Calculate target value
        target_value = self._calculate_target_value(
            goal_key, template, current_value, difficulty, health_patterns
        )
        
        # Calculate timeline
        timeline_days = self._calculate_timeline(
            goal_key, template, current_value, target_value, difficulty
        )
        
        # Calculate success probability
        success_probability = self._calculate_success_probability(
            goal_key, current_value, target_value, health_patterns, difficulty
        )
        
        # Generate reasoning and benefits
        reasoning = self._generate_reasoning(
            goal_key, current_value, target_value, health_patterns, correlations
        )
        
        expected_benefits = template["benefits"].copy()
        if correlations:
            expected_benefits.extend(self._get_correlation_benefits(goal_key, correlations))
        
        # Generate required actions
        required_actions = self._generate_required_actions(
            goal_key, current_value, target_value, health_patterns
        )
        
        # Identify related metrics
        related_metrics = self._identify_related_metrics(goal_key, correlations)
        
        # Generate adjustment triggers
        adjustment_triggers = self._generate_adjustment_triggers(goal_key, template)
        
        # Calculate confidence score
        confidence_score = self._calculate_confidence_score(
            current_metrics, health_patterns, success_probability
        )
        
        return GoalRecommendation(
            id=f"{goal_key}_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            category=template["category"],
            goal_type=template["goal_type"],
            title=self._generate_goal_title(goal_key, target_value, template),
            description=self._generate_goal_description(goal_key, current_value, target_value, template),
            target_value=target_value,
            current_value=current_value,
            unit=template["unit"],
            difficulty=difficulty,
            timeline_days=timeline_days,
            confidence_score=confidence_score,
            reasoning=reasoning,
            expected_benefits=expected_benefits[:5],  # Limit to top 5 benefits
            success_probability=success_probability,
            required_actions=required_actions,
            related_metrics=related_metrics,
            adjustment_triggers=adjustment_triggers
        )
    
    def _get_metric_key_for_goal(self, goal_key: str) -> str:
        """Map goal keys to metric keys"""
        mapping = {
            "daily_steps": "steps",
            "sleep_duration": "sleep_duration",
            "water_intake": "water_intake",
            "weight_loss": "weight",
            "resting_heart_rate": "resting_heart_rate"
        }
        return mapping.get(goal_key, goal_key)
    
    def _determine_optimal_difficulty(
        self,
        goal_key: str,
        current_metrics: Dict,
        health_patterns: Dict
    ) -> GoalDifficulty:
        """Determine optimal difficulty based on user patterns and capabilities"""
        
        # Analyze user's historical performance
        consistency_score = health_patterns.get("consistency_score", 0.5)
        improvement_trend = health_patterns.get("improvement_trend", 0.0)
        goal_achievement_rate = health_patterns.get("goal_achievement_rate", 0.5)
        
        # Calculate difficulty score
        difficulty_score = (consistency_score * 0.4 + 
                          (improvement_trend + 1) / 2 * 0.3 + 
                          goal_achievement_rate * 0.3)
        
        if difficulty_score >= 0.8:
            return GoalDifficulty.CHALLENGING
        elif difficulty_score >= 0.6:
            return GoalDifficulty.MODERATE
        elif difficulty_score >= 0.4:
            return GoalDifficulty.EASY
        else:
            return GoalDifficulty.EASY
    
    def _calculate_target_value(
        self,
        goal_key: str,
        template: Dict,
        current_value: float,
        difficulty: GoalDifficulty,
        health_patterns: Dict
    ) -> float:
        """Calculate appropriate target value for the goal"""
        
        difficulty_multiplier = self.difficulty_multipliers[difficulty]
        
        if template["goal_type"] == GoalType.INCREASE:
            base_increase = template.get("min_increase", template["baseline_target"] * 0.1)
            max_increase = template.get("max_increase", template["baseline_target"] * 0.5)
            increase = base_increase + (max_increase - base_increase) * (difficulty_multiplier - 0.7) / 0.9
            return current_value + increase
            
        elif template["goal_type"] == GoalType.DECREASE:
            base_decrease = template.get("min_target", template["baseline_target"] * 0.1)
            max_decrease = template.get("max_target", template["baseline_target"] * 0.3)
            decrease = base_decrease + (max_decrease - base_decrease) * (difficulty_multiplier - 0.7) / 0.9
            return max(current_value - decrease, 0)
            
        elif template["goal_type"] == GoalType.ACHIEVE:
            target = template["baseline_target"]
            if current_value < target:
                gap = target - current_value
                return current_value + gap * difficulty_multiplier
            else:
                return target
                
        else:  # MAINTAIN
            return current_value
    
    def _calculate_timeline(
        self,
        goal_key: str,
        template: Dict,
        current_value: float,
        target_value: float,
        difficulty: GoalDifficulty
    ) -> int:
        """Calculate appropriate timeline for achieving the goal"""
        
        min_days, max_days = template["timeline_range"]
        
        # Adjust timeline based on difficulty
        if difficulty == GoalDifficulty.EASY:
            return min_days
        elif difficulty == GoalDifficulty.MODERATE:
            return int((min_days + max_days) / 2)
        elif difficulty == GoalDifficulty.CHALLENGING:
            return int(max_days * 0.8)
        else:  # AMBITIOUS
            return max_days
    
    def _calculate_success_probability(
        self,
        goal_key: str,
        current_value: float,
        target_value: float,
        health_patterns: Dict,
        difficulty: GoalDifficulty
    ) -> float:
        """Calculate probability of successfully achieving the goal"""
        
        # Base probability based on difficulty
        base_probabilities = {
            GoalDifficulty.EASY: 0.85,
            GoalDifficulty.MODERATE: 0.70,
            GoalDifficulty.CHALLENGING: 0.55,
            GoalDifficulty.AMBITIOUS: 0.40
        }
        
        base_prob = base_probabilities[difficulty]
        
        # Adjust based on user patterns
        consistency_score = health_patterns.get("consistency_score", 0.5)
        improvement_trend = health_patterns.get("improvement_trend", 0.0)
        
        # Consistency bonus/penalty
        consistency_adjustment = (consistency_score - 0.5) * 0.2
        
        # Trend bonus/penalty
        trend_adjustment = max(-0.1, min(0.1, improvement_trend * 0.1))
        
        final_probability = base_prob + consistency_adjustment + trend_adjustment
        return max(0.1, min(0.95, final_probability))
    
    def _generate_reasoning(
        self,
        goal_key: str,
        current_value: float,
        target_value: float,
        health_patterns: Dict,
        correlations: Dict
    ) -> str:
        """Generate reasoning for the goal recommendation"""
        
        reasoning_templates = {
            "daily_steps": f"Based on your current activity level of {current_value:,.0f} steps, increasing to {target_value:,.0f} steps will improve your cardiovascular health and energy levels.",
            "sleep_duration": f"Your current sleep duration of {current_value:.1f} hours can be optimized to {target_value:.1f} hours for better recovery and cognitive performance.",
            "water_intake": f"Increasing your water intake from {current_value:.1f}L to {target_value:.1f}L will improve hydration and support your metabolism.",
            "weight_loss": f"A gradual reduction from {current_value:.1f}kg to {target_value:.1f}kg will improve your health markers and overall well-being.",
            "resting_heart_rate": f"Reducing your resting heart rate from {current_value:.0f} to {target_value:.0f} bpm indicates improved cardiovascular fitness."
        }
        
        base_reasoning = reasoning_templates.get(goal_key, f"Improving from {current_value} to {target_value} will benefit your health.")
        
        # Add pattern-based insights
        if health_patterns.get("consistency_score", 0) > 0.7:
            base_reasoning += " Your consistent health habits suggest you're well-positioned to achieve this goal."
        
        # Add correlation insights
        if correlations and goal_key in correlations:
            base_reasoning += f" This improvement may also positively impact your {', '.join(correlations[goal_key][:2])}."
        
        return base_reasoning
    
    def _get_correlation_benefits(self, goal_key: str, correlations: Dict) -> List[str]:
        """Get additional benefits based on correlations"""
        correlation_benefits = {
            "daily_steps": ["Better sleep quality", "Improved mood"],
            "sleep_duration": ["Enhanced recovery", "Better focus"],
            "water_intake": ["Clearer skin", "Better digestion"],
            "weight_loss": ["Improved mobility", "Better self-confidence"],
            "resting_heart_rate": ["Enhanced endurance", "Better stress management"]
        }
        return correlation_benefits.get(goal_key, [])
    
    def _generate_required_actions(
        self,
        goal_key: str,
        current_value: float,
        target_value: float,
        health_patterns: Dict
    ) -> List[str]:
        """Generate specific actions required to achieve the goal"""
        
        action_templates = {
            "daily_steps": [
                "Take a 10-minute walk after each meal",
                "Use stairs instead of elevators",
                "Park further away from destinations",
                "Set hourly movement reminders"
            ],
            "sleep_duration": [
                "Establish a consistent bedtime routine",
                "Limit screen time 1 hour before bed",
                "Create a comfortable sleep environment",
                "Avoid caffeine after 2 PM"
            ],
            "water_intake": [
                "Drink a glass of water upon waking",
                "Carry a water bottle throughout the day",
                "Set hydration reminders",
                "Flavor water with lemon or cucumber"
            ],
            "weight_loss": [
                "Track your food intake",
                "Increase protein consumption",
                "Reduce portion sizes gradually",
                "Incorporate strength training"
            ],
            "resting_heart_rate": [
                "Engage in regular cardio exercise",
                "Practice stress management techniques",
                "Ensure adequate recovery between workouts",
                "Monitor heart rate during activities"
            ]
        }
        
        return action_templates.get(goal_key, ["Follow a structured plan", "Monitor progress regularly"])
    
    def _identify_related_metrics(self, goal_key: str, correlations: Dict) -> List[str]:
        """Identify metrics related to the goal"""
        
        related_mapping = {
            "daily_steps": ["active_energy", "heart_rate", "sleep_quality"],
            "sleep_duration": ["recovery_score", "resting_heart_rate", "mood"],
            "water_intake": ["skin_health", "energy_levels", "digestion"],
            "weight_loss": ["body_fat_percentage", "muscle_mass", "BMI"],
            "resting_heart_rate": ["cardiovascular_fitness", "stress_levels", "recovery"]
        }
        
        return related_mapping.get(goal_key, [])
    
    def _generate_adjustment_triggers(self, goal_key: str, template: Dict) -> List[str]:
        """Generate triggers that would warrant goal adjustment"""
        
        return [
            "Consistently exceeding target for 7+ days",
            "Unable to make progress for 14+ days",
            "Significant life changes affecting routine",
            "Health issues or injuries",
            "Achievement of related health milestones"
        ]
    
    def _calculate_confidence_score(
        self,
        current_metrics: Dict,
        health_patterns: Dict,
        success_probability: float
    ) -> float:
        """Calculate confidence score for the recommendation"""
        
        # Factors affecting confidence
        data_completeness = len(current_metrics) / 10  # Assume 10 key metrics
        pattern_reliability = health_patterns.get("data_quality_score", 0.5)
        
        confidence = (data_completeness * 0.3 + 
                     pattern_reliability * 0.4 + 
                     success_probability * 0.3)
        
        return max(0.1, min(0.95, confidence))
    
    def _generate_goal_title(self, goal_key: str, target_value: float, template: Dict) -> str:
        """Generate a compelling goal title"""
        
        titles = {
            "daily_steps": f"Reach {target_value:,.0f} Daily Steps",
            "sleep_duration": f"Achieve {target_value:.1f} Hours of Sleep",
            "water_intake": f"Drink {target_value:.1f}L of Water Daily",
            "weight_loss": f"Reach Target Weight of {target_value:.1f}kg",
            "resting_heart_rate": f"Lower Resting Heart Rate to {target_value:.0f} BPM"
        }
        
        return titles.get(goal_key, f"Improve {goal_key.replace('_', ' ').title()}")
    
    def _generate_goal_description(
        self,
        goal_key: str,
        current_value: float,
        target_value: float,
        template: Dict
    ) -> str:
        """Generate a detailed goal description"""
        
        descriptions = {
            "daily_steps": f"Increase your daily step count from {current_value:,.0f} to {target_value:,.0f} steps to improve cardiovascular health and maintain an active lifestyle.",
            "sleep_duration": f"Optimize your sleep duration from {current_value:.1f} to {target_value:.1f} hours per night for better recovery, cognitive function, and overall health.",
            "water_intake": f"Increase your daily water intake from {current_value:.1f}L to {target_value:.1f}L to improve hydration, support metabolism, and enhance overall well-being.",
            "weight_loss": f"Achieve a healthy weight reduction from {current_value:.1f}kg to {target_value:.1f}kg through sustainable lifestyle changes.",
            "resting_heart_rate": f"Improve cardiovascular fitness by reducing your resting heart rate from {current_value:.0f} to {target_value:.0f} BPM through regular exercise and stress management."
        }
        
        return descriptions.get(goal_key, f"Work towards improving your {goal_key.replace('_', ' ')} for better health outcomes.")
    
    def _rank_recommendations(
        self,
        recommendations: List[GoalRecommendation],
        health_patterns: Dict
    ) -> List[GoalRecommendation]:
        """Rank recommendations by priority and potential impact"""
        
        def calculate_priority_score(rec: GoalRecommendation) -> float:
            # Factors for ranking
            confidence_weight = 0.3
            success_probability_weight = 0.3
            health_impact_weight = 0.4
            
            # Health impact based on category
            impact_scores = {
                GoalCategory.ACTIVITY: 0.9,
                GoalCategory.SLEEP: 0.85,
                GoalCategory.HEART_HEALTH: 0.8,
                GoalCategory.NUTRITION: 0.75,
                GoalCategory.BODY_COMPOSITION: 0.7,
                GoalCategory.WELLNESS: 0.6
            }
            
            health_impact = impact_scores.get(rec.category, 0.5)
            
            return (rec.confidence_score * confidence_weight +
                   rec.success_probability * success_probability_weight +
                   health_impact * health_impact_weight)
        
        return sorted(recommendations, key=calculate_priority_score, reverse=True)
    
    def _coordinate_goals(self, recommendations: List[GoalRecommendation]) -> List[GoalRecommendation]:
        """Ensure goals are coordinated and don't conflict"""
        
        # Check for conflicting goals
        coordinated = []
        categories_used = set()
        
        for rec in recommendations:
            # Avoid multiple goals in the same category for now
            if rec.category not in categories_used:
                coordinated.append(rec)
                categories_used.add(rec.category)
        
        return coordinated
    
    async def _get_user_health_data(self, user_id: int, db: Session) -> Optional[pd.DataFrame]:
        """Retrieve user health data for analysis"""
        try:
            # Get recent health data (last 90 days)
            end_date = datetime.now()
            start_date = end_date - timedelta(days=90)
            
            health_data = db.query(HealthData).filter(
                HealthData.user_id == user_id,
                HealthData.recorded_at >= start_date,
                HealthData.recorded_at <= end_date
            ).all()
            
            if not health_data:
                return None
            
            # Convert to DataFrame
            data_list = []
            for record in health_data:
                data_list.append({
                    'date': record.recorded_at.date(),
                    'metric_type': record.metric_type,
                    'value': record.value,
                    'unit': record.unit,
                    'source': record.source
                })
            
            return pd.DataFrame(data_list)
            
        except Exception as e:
            logger.error(f"Error retrieving user health data: {e}")
            return None
    
    def _calculate_current_metrics(self, user_data: pd.DataFrame) -> Dict[str, float]:
        """Calculate current metric values from user data"""
        try:
            current_metrics = {}
            
            # Group by metric type and calculate recent averages
            for metric_type in user_data['metric_type'].unique():
                metric_data = user_data[user_data['metric_type'] == metric_type]
                
                # Use last 7 days average for current value
                recent_data = metric_data.tail(7)
                if not recent_data.empty:
                    current_metrics[metric_type] = recent_data['value'].mean()
            
            return current_metrics
            
        except Exception as e:
            logger.error(f"Error calculating current metrics: {e}")
            return {}

    async def adjust_goal(
        self,
        goal_id: str,
        user_id: int,
        db: Session,
        progress_data: Dict[str, Any]
    ) -> Optional[GoalAdjustment]:
        """
        Dynamically adjust a goal based on user progress and changing circumstances.
        
        Args:
            goal_id: Goal identifier
            user_id: User identifier
            db: Database session
            progress_data: Current progress information
            
        Returns:
            Goal adjustment recommendation
        """
        try:
            logger.info(f"Analyzing goal adjustment for goal {goal_id}")
            
            # Analyze current progress
            current_performance = progress_data.get('current_value', 0)
            target_value = progress_data.get('target_value', 0)
            days_elapsed = progress_data.get('days_elapsed', 0)
            total_timeline = progress_data.get('total_timeline', 30)
            
            # Calculate progress rate
            expected_progress = (days_elapsed / total_timeline) if total_timeline > 0 else 0
            actual_progress = self._calculate_actual_progress(
                progress_data.get('initial_value', 0),
                current_performance,
                target_value
            )
            
            # Determine if adjustment is needed
            adjustment_needed = self._assess_adjustment_need(
                expected_progress, actual_progress, days_elapsed
            )
            
            if not adjustment_needed:
                return None
            
            # Generate adjustment recommendation
            adjustment_type = self._determine_adjustment_type(
                expected_progress, actual_progress, current_performance, target_value
            )
            
            new_target = self._calculate_adjusted_target(
                adjustment_type, current_performance, target_value, 
                actual_progress, expected_progress
            )
            
            reasoning = self._generate_adjustment_reasoning(
                adjustment_type, expected_progress, actual_progress, 
                current_performance, target_value
            )
            
            confidence = self._calculate_adjustment_confidence(
                days_elapsed, actual_progress, expected_progress
            )
            
            expected_impact = self._predict_adjustment_impact(
                adjustment_type, current_performance, new_target
            )
            
            return GoalAdjustment(
                goal_id=goal_id,
                adjustment_type=adjustment_type,
                new_target=new_target,
                reasoning=reasoning,
                confidence=confidence,
                expected_impact=expected_impact
            )
            
        except Exception as e:
            logger.error(f"Error adjusting goal: {e}")
            return None
    
    def _calculate_actual_progress(
        self, 
        initial_value: float, 
        current_value: float, 
        target_value: float
    ) -> float:
        """Calculate actual progress as a percentage"""
        if target_value == initial_value:
            return 1.0
        
        progress = (current_value - initial_value) / (target_value - initial_value)
        return max(0.0, min(1.0, progress))
    
    def _assess_adjustment_need(
        self, 
        expected_progress: float, 
        actual_progress: float, 
        days_elapsed: int
    ) -> bool:
        """Assess if goal adjustment is needed"""
        
        # Don't adjust too early
        if days_elapsed < 7:
            return False
        
        # Significant deviation from expected progress
        progress_deviation = abs(actual_progress - expected_progress)
        
        # Adjust if deviation is > 20% and we're past the first week
        return progress_deviation > 0.2
    
    def _determine_adjustment_type(
        self,
        expected_progress: float,
        actual_progress: float,
        current_value: float,
        target_value: float
    ) -> str:
        """Determine the type of adjustment needed"""
        
        if actual_progress > expected_progress + 0.2:
            return "increase_target"  # User is exceeding expectations
        elif actual_progress < expected_progress - 0.3:
            return "decrease_target"  # User is struggling significantly
        elif actual_progress < expected_progress - 0.2:
            return "extend_timeline"  # User needs more time
        else:
            return "maintain"  # No adjustment needed
    
    def _calculate_adjusted_target(
        self,
        adjustment_type: str,
        current_value: float,
        original_target: float,
        actual_progress: float,
        expected_progress: float
    ) -> float:
        """Calculate the new target value"""
        
        if adjustment_type == "increase_target":
            # Increase target by 15-25% based on over-performance
            over_performance = actual_progress - expected_progress
            increase_factor = 1.15 + (over_performance * 0.5)
            return original_target * increase_factor
            
        elif adjustment_type == "decrease_target":
            # Decrease target to be more achievable
            under_performance = expected_progress - actual_progress
            decrease_factor = 0.85 - (under_performance * 0.3)
            return original_target * max(0.7, decrease_factor)
            
        elif adjustment_type == "extend_timeline":
            # Keep same target but extend timeline (handled elsewhere)
            return original_target
            
        else:
            return original_target
    
    def _generate_adjustment_reasoning(
        self,
        adjustment_type: str,
        expected_progress: float,
        actual_progress: float,
        current_value: float,
        target_value: float
    ) -> str:
        """Generate reasoning for the adjustment"""
        
        reasoning_templates = {
            "increase_target": f"You're exceeding expectations with {actual_progress:.1%} progress vs expected {expected_progress:.1%}. Let's challenge you with a higher target to maximize your potential.",
            "decrease_target": f"Your current progress of {actual_progress:.1%} is below the expected {expected_progress:.1%}. Let's adjust to a more achievable target to maintain motivation.",
            "extend_timeline": f"You're making steady progress at {actual_progress:.1%} but need more time. Let's extend the timeline while keeping the same ambitious target.",
            "maintain": "Your progress is on track. No adjustment needed at this time."
        }
        
        return reasoning_templates.get(adjustment_type, "Goal adjustment recommended based on current progress.")
    
    def _calculate_adjustment_confidence(
        self,
        days_elapsed: int,
        actual_progress: float,
        expected_progress: float
    ) -> float:
        """Calculate confidence in the adjustment recommendation"""
        
        # More data = higher confidence
        time_confidence = min(1.0, days_elapsed / 14)  # Max confidence after 2 weeks
        
        # Clear deviation = higher confidence
        deviation = abs(actual_progress - expected_progress)
        deviation_confidence = min(1.0, deviation * 2)  # Max confidence at 50% deviation
        
        return (time_confidence * 0.6 + deviation_confidence * 0.4)
    
    def _predict_adjustment_impact(
        self,
        adjustment_type: str,
        current_value: float,
        new_target: float
    ) -> str:
        """Predict the impact of the adjustment"""
        
        impact_descriptions = {
            "increase_target": "This adjustment will provide a greater challenge and potentially lead to better results than originally planned.",
            "decrease_target": "This adjustment will make the goal more achievable and help maintain motivation and consistency.",
            "extend_timeline": "This adjustment provides more time to achieve the goal without compromising the target outcome.",
            "maintain": "Continuing with the current goal parameters is optimal for your progress."
        }
        
        return impact_descriptions.get(adjustment_type, "This adjustment will optimize your goal achievement.")

    async def coordinate_multiple_goals(
        self,
        goal_ids: List[str],
        user_id: int,
        db: Session
    ) -> List[GoalCoordination]:
        """
        Coordinate multiple goals to ensure they work together synergistically.
        
        Args:
            goal_ids: List of goal identifiers
            user_id: User identifier
            db: Database session
            
        Returns:
            List of goal coordination recommendations
        """
        try:
            logger.info(f"Coordinating {len(goal_ids)} goals for user {user_id}")
            
            # Get goal details (this would typically come from a goals table)
            # For now, we'll simulate goal coordination logic
            
            coordinations = []
            
            # Identify synergistic goal pairs
            synergistic_pairs = self._identify_synergistic_goals(goal_ids)
            
            for primary_goal, related_goals in synergistic_pairs.items():
                coordination = self._create_goal_coordination(
                    primary_goal, related_goals
                )
                if coordination:
                    coordinations.append(coordination)
            
            return coordinations
            
        except Exception as e:
            logger.error(f"Error coordinating goals: {e}")
            return []
    
    def _identify_synergistic_goals(self, goal_ids: List[str]) -> Dict[str, List[str]]:
        """Identify goals that work well together"""
        
        # Define synergistic relationships
        synergies = {
            "daily_steps": ["weight_loss", "resting_heart_rate"],
            "sleep_duration": ["resting_heart_rate", "weight_loss"],
            "water_intake": ["weight_loss"],
            "weight_loss": ["daily_steps", "sleep_duration"],
            "resting_heart_rate": ["daily_steps", "sleep_duration"]
        }
        
        synergistic_pairs = {}
        
        for goal_id in goal_ids:
            goal_type = self._extract_goal_type(goal_id)
            if goal_type in synergies:
                related = [g for g in goal_ids if self._extract_goal_type(g) in synergies[goal_type]]
                if related:
                    synergistic_pairs[goal_id] = related
        
        return synergistic_pairs
    
    def _extract_goal_type(self, goal_id: str) -> str:
        """Extract goal type from goal ID"""
        # Assuming goal_id format: "goal_type_timestamp"
        return goal_id.split('_')[0] + '_' + goal_id.split('_')[1] if '_' in goal_id else goal_id
    
    def _create_goal_coordination(
        self,
        primary_goal_id: str,
        related_goal_ids: List[str]
    ) -> Optional[GoalCoordination]:
        """Create a goal coordination recommendation"""
        
        primary_type = self._extract_goal_type(primary_goal_id)
        
        coordination_templates = {
            "daily_steps": {
                "coordination_type": "activity_synergy",
                "impact_description": "Increased daily steps will support weight loss and improve cardiovascular health, reducing resting heart rate.",
                "optimization_suggestions": [
                    "Schedule walks during times that don't interfere with sleep goals",
                    "Use step goals as active recovery between intense workouts",
                    "Track heart rate during walks to monitor cardiovascular improvements"
                ]
            },
            "sleep_duration": {
                "coordination_type": "recovery_optimization",
                "impact_description": "Better sleep will improve recovery, supporting both weight management and cardiovascular health.",
                "optimization_suggestions": [
                    "Avoid intense exercise 3 hours before target bedtime",
                    "Use sleep quality to adjust next-day activity intensity",
                    "Monitor how sleep affects weight and heart rate trends"
                ]
            },
            "weight_loss": {
                "coordination_type": "metabolic_synergy",
                "impact_description": "Weight loss will be supported by increased activity and better sleep, creating a positive feedback loop.",
                "optimization_suggestions": [
                    "Align caloric deficit with activity level increases",
                    "Use weight trends to adjust activity goals",
                    "Ensure adequate sleep to support metabolism and recovery"
                ]
            }
        }
        
        template = coordination_templates.get(primary_type)
        if not template:
            return None
        
        return GoalCoordination(
            primary_goal_id=primary_goal_id,
            related_goal_ids=related_goal_ids,
            coordination_type=template["coordination_type"],
            impact_description=template["impact_description"],
            optimization_suggestions=template["optimization_suggestions"]
        ) 
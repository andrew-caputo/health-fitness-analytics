"""
Health Coaching Engine

This module provides personalized health coaching through AI-generated messages,
behavioral interventions, and motivational content based on user health patterns and progress.
"""

import logging
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
from dataclasses import dataclass
from enum import Enum
import pandas as pd
from sqlalchemy.orm import Session

from ..core.models import HealthData
from .pattern_recognition import PatternRecognizer
from .health_insights_engine import HealthInsightsEngine

logger = logging.getLogger(__name__)

class CoachingType(Enum):
    """Types of coaching interventions"""
    MOTIVATIONAL = "motivational"
    EDUCATIONAL = "educational"
    BEHAVIORAL = "behavioral"
    CORRECTIVE = "corrective"
    CELEBRATORY = "celebratory"
    PREVENTIVE = "preventive"

class InterventionTiming(Enum):
    """When to deliver interventions"""
    IMMEDIATE = "immediate"
    DAILY = "daily"
    WEEKLY = "weekly"
    MILESTONE = "milestone"
    STRUGGLE = "struggle"

@dataclass
class CoachingMessage:
    """Represents a personalized coaching message"""
    id: str
    coaching_type: CoachingType
    title: str
    message: str
    timing: InterventionTiming
    priority: int  # 1-5, 5 being highest
    target_metrics: List[str]
    actionable_steps: List[str]
    expected_outcome: str
    follow_up_days: int
    personalization_factors: List[str]

@dataclass
class BehavioralIntervention:
    """Represents a behavioral change intervention"""
    id: str
    intervention_type: str
    target_behavior: str
    current_pattern: str
    desired_pattern: str
    intervention_strategy: str
    implementation_steps: List[str]
    success_metrics: List[str]
    timeline_days: int
    difficulty_level: str

class HealthCoach:
    """
    AI-powered health coaching engine that provides personalized guidance,
    behavioral interventions, and motivational support.
    """
    
    def __init__(self):
        self.pattern_recognizer = PatternRecognizer()
        self.insights_engine = HealthInsightsEngine()
        
        # Coaching templates and strategies
        self.coaching_templates = self._initialize_coaching_templates()
        self.intervention_strategies = self._initialize_intervention_strategies()
        self.motivational_frameworks = self._initialize_motivational_frameworks()
    
    def _initialize_coaching_templates(self) -> Dict[str, Dict]:
        """Initialize coaching message templates"""
        return {
            "progress_celebration": {
                "type": CoachingType.CELEBRATORY,
                "templates": [
                    "🎉 Amazing progress! You've improved your {metric} by {improvement}% this week!",
                    "🌟 Fantastic work! Your consistency in {metric} is paying off with {improvement}% improvement!",
                    "🏆 Outstanding! You've exceeded your {metric} goal by {excess}%!"
                ]
            },
            "gentle_motivation": {
                "type": CoachingType.MOTIVATIONAL,
                "templates": [
                    "💪 Every small step counts! Your {metric} shows you're on the right track.",
                    "🌱 Progress takes time. Your {metric} improvements show you're building healthy habits.",
                    "⭐ Keep going! Your {metric} trend is moving in the right direction."
                ]
            },
            "behavioral_guidance": {
                "type": CoachingType.BEHAVIORAL,
                "templates": [
                    "🎯 Try this: {specific_action} to improve your {metric}.",
                    "💡 Based on your patterns, {behavioral_suggestion} could help with {metric}.",
                    "🔄 Consider adjusting your {routine_aspect} to optimize {metric}."
                ]
            },
            "educational_insight": {
                "type": CoachingType.EDUCATIONAL,
                "templates": [
                    "📚 Did you know? {health_fact} This explains why your {metric} matters.",
                    "🧠 Science shows that {research_insight} affects {metric}.",
                    "💡 Understanding: {explanation} helps explain your {metric} patterns."
                ]
            }
        }
    
    def _initialize_intervention_strategies(self) -> Dict[str, Dict]:
        """Initialize behavioral intervention strategies"""
        return {
            "habit_formation": {
                "strategy": "Start small and build consistency",
                "steps": [
                    "Choose one specific time for the activity",
                    "Start with just 5 minutes daily",
                    "Track completion for visual progress",
                    "Gradually increase duration/intensity",
                    "Celebrate small wins"
                ],
                "timeline": 21
            },
            "barrier_removal": {
                "strategy": "Identify and eliminate obstacles",
                "steps": [
                    "List current barriers to the behavior",
                    "Prioritize barriers by impact",
                    "Create specific solutions for each barrier",
                    "Test solutions one at a time",
                    "Adjust based on results"
                ],
                "timeline": 14
            },
            "social_support": {
                "strategy": "Leverage social connections",
                "steps": [
                    "Share goals with supportive friends/family",
                    "Find an accountability partner",
                    "Join relevant communities or groups",
                    "Schedule regular check-ins",
                    "Celebrate achievements together"
                ],
                "timeline": 30
            }
        }
    
    def _initialize_motivational_frameworks(self) -> Dict[str, List[str]]:
        """Initialize motivational messaging frameworks"""
        return {
            "growth_mindset": [
                "Your brain is like a muscle - it gets stronger with practice",
                "Challenges are opportunities to grow and improve",
                "Every setback is a setup for a comeback",
                "Progress, not perfection, is the goal"
            ],
            "self_efficacy": [
                "You have the power to change your health",
                "Your past successes show you can do this",
                "You're building skills that will serve you for life",
                "Trust in your ability to make positive changes"
            ],
            "intrinsic_motivation": [
                "Focus on how good healthy choices make you feel",
                "Remember why you started this journey",
                "Celebrate the energy and vitality you're gaining",
                "You're investing in your future self"
            ]
        }
    
    async def generate_coaching_messages(
        self,
        user_id: int,
        db: Session,
        message_count: int = 3
    ) -> List[CoachingMessage]:
        """Generate personalized coaching messages for a user"""
        try:
            logger.info(f"Generating coaching messages for user {user_id}")
            
            # Get user health data and patterns
            user_data = await self._get_user_health_data(user_id, db, 30)
            if user_data is None or user_data.empty:
                return self._generate_default_messages()
            
            health_patterns = await self.pattern_recognizer.analyze_patterns(user_data)
            recent_progress = self._analyze_recent_progress(user_data)
            
            messages = []
            
            # Generate different types of messages based on user state
            if recent_progress.get("has_improvements", False):
                celebration_msg = self._generate_celebration_message(recent_progress)
                if celebration_msg:
                    messages.append(celebration_msg)
            
            if recent_progress.get("has_struggles", False):
                support_msg = self._generate_support_message(recent_progress, health_patterns)
                if support_msg:
                    messages.append(support_msg)
            
            # Always include motivational message
            motivational_msg = self._generate_motivational_message(health_patterns)
            if motivational_msg:
                messages.append(motivational_msg)
            
            # Add educational content if space allows
            if len(messages) < message_count:
                educational_msg = self._generate_educational_message(user_data)
                if educational_msg:
                    messages.append(educational_msg)
            
            return messages[:message_count]
            
        except Exception as e:
            logger.error(f"Error generating coaching messages: {e}")
            return self._generate_default_messages()
    
    async def create_behavioral_intervention(
        self,
        user_id: int,
        db: Session,
        target_behavior: str
    ) -> Optional[BehavioralIntervention]:
        """Create a personalized behavioral intervention plan"""
        try:
            user_data = await self._get_user_health_data(user_id, db, 60)
            if user_data is None:
                return None
            
            # Analyze current behavior patterns
            current_pattern = self._analyze_behavior_pattern(user_data, target_behavior)
            
            # Determine appropriate intervention strategy
            strategy_key = self._select_intervention_strategy(current_pattern)
            strategy = self.intervention_strategies[strategy_key]
            
            # Create personalized intervention
            intervention_id = f"intervention_{target_behavior}_{user_id}_{datetime.now().strftime('%Y%m%d')}"
            
            return BehavioralIntervention(
                id=intervention_id,
                intervention_type=strategy_key,
                target_behavior=target_behavior,
                current_pattern=current_pattern["description"],
                desired_pattern=self._define_desired_pattern(target_behavior),
                intervention_strategy=strategy["strategy"],
                implementation_steps=strategy["steps"],
                success_metrics=self._define_success_metrics(target_behavior),
                timeline_days=strategy["timeline"],
                difficulty_level=self._assess_difficulty_level(current_pattern)
            )
            
        except Exception as e:
            logger.error(f"Error creating behavioral intervention: {e}")
            return None
    
    def _generate_celebration_message(self, progress: Dict) -> Optional[CoachingMessage]:
        """Generate a celebration message for recent improvements"""
        improvements = progress.get("improvements", {})
        if not improvements:
            return None
        
        # Find the most significant improvement
        best_metric = max(improvements.keys(), key=lambda k: improvements[k])
        improvement_value = improvements[best_metric]
        
        template = self.coaching_templates["progress_celebration"]["templates"][0]
        message = template.format(metric=best_metric, improvement=improvement_value)
        
        return CoachingMessage(
            id=f"celebration_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            coaching_type=CoachingType.CELEBRATORY,
            title="Celebrating Your Progress! 🎉",
            message=message,
            timing=InterventionTiming.IMMEDIATE,
            priority=4,
            target_metrics=[best_metric],
            actionable_steps=[
                f"Keep up your current {best_metric} routine",
                "Consider setting a slightly more challenging goal",
                "Share your success with someone who supports you"
            ],
            expected_outcome="Maintained motivation and continued progress",
            follow_up_days=7,
            personalization_factors=["recent_improvement", "positive_reinforcement"]
        )
    
    def _generate_support_message(self, progress: Dict, patterns: Dict) -> Optional[CoachingMessage]:
        """Generate a supportive message for struggles"""
        struggles = progress.get("struggles", {})
        if not struggles:
            return None
        
        struggling_metric = list(struggles.keys())[0]
        
        # Provide gentle, supportive guidance
        message = f"💙 I notice your {struggling_metric} has been challenging lately. Remember, every journey has ups and downs. What matters is that you keep moving forward. Small, consistent steps will get you there."
        
        return CoachingMessage(
            id=f"support_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            coaching_type=CoachingType.MOTIVATIONAL,
            title="You've Got This! 💪",
            message=message,
            timing=InterventionTiming.IMMEDIATE,
            priority=5,
            target_metrics=[struggling_metric],
            actionable_steps=[
                f"Focus on just one small improvement in {struggling_metric}",
                "Review what worked well in the past",
                "Consider if any barriers need to be addressed"
            ],
            expected_outcome="Renewed motivation and clearer action plan",
            follow_up_days=3,
            personalization_factors=["struggling_area", "emotional_support"]
        )
    
    def _generate_motivational_message(self, patterns: Dict) -> CoachingMessage:
        """Generate a general motivational message"""
        consistency_score = patterns.get("consistency_score", 0.5)
        
        if consistency_score > 0.7:
            framework = "self_efficacy"
            message = "🌟 Your consistency is impressive! You're proving to yourself that you can maintain healthy habits. This foundation will serve you well in reaching all your health goals."
        else:
            framework = "growth_mindset"
            message = "🌱 Building healthy habits is a journey, not a destination. Every day you choose to prioritize your health, you're growing stronger. Progress takes time, and you're exactly where you need to be."
        
        return CoachingMessage(
            id=f"motivation_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            coaching_type=CoachingType.MOTIVATIONAL,
            title="Daily Motivation ✨",
            message=message,
            timing=InterventionTiming.DAILY,
            priority=3,
            target_metrics=["overall_wellness"],
            actionable_steps=[
                "Take a moment to appreciate your progress",
                "Set one small health intention for today",
                "Remember your 'why' for pursuing better health"
            ],
            expected_outcome="Increased motivation and positive mindset",
            follow_up_days=1,
            personalization_factors=[framework, "daily_encouragement"]
        )
    
    def _generate_educational_message(self, user_data: pd.DataFrame) -> Optional[CoachingMessage]:
        """Generate an educational message based on user data"""
        # Find the most tracked metric to provide relevant education
        metric_counts = user_data['metric_type'].value_counts()
        if metric_counts.empty:
            return None
        
        top_metric = metric_counts.index[0]
        
        educational_content = {
            "steps": {
                "fact": "Walking 10,000 steps burns approximately 400-500 calories",
                "insight": "Regular walking strengthens your heart, improves mood, and boosts energy levels"
            },
            "sleep_duration": {
                "fact": "During deep sleep, your brain clears toxins that accumulate during the day",
                "insight": "Quality sleep is when your body repairs muscles and consolidates memories"
            },
            "water_intake": {
                "fact": "Your body is about 60% water, and even mild dehydration affects performance",
                "insight": "Proper hydration supports every cellular function in your body"
            }
        }
        
        content = educational_content.get(top_metric, {
            "fact": "Small, consistent changes compound into significant health improvements",
            "insight": "Your daily choices are investments in your future health and wellbeing"
        })
        
        message = f"📚 Health Insight: {content['fact']}. {content['insight']}. This is why tracking your {top_metric} matters for your overall health journey."
        
        return CoachingMessage(
            id=f"education_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
            coaching_type=CoachingType.EDUCATIONAL,
            title="Health Knowledge 🧠",
            message=message,
            timing=InterventionTiming.WEEKLY,
            priority=2,
            target_metrics=[top_metric],
            actionable_steps=[
                f"Apply this knowledge to optimize your {top_metric}",
                "Share this insight with someone who might benefit",
                "Reflect on how this connects to your health goals"
            ],
            expected_outcome="Increased understanding and motivation",
            follow_up_days=7,
            personalization_factors=["educational_content", "knowledge_building"]
        )
    
    def _analyze_recent_progress(self, user_data: pd.DataFrame) -> Dict:
        """Analyze recent progress patterns"""
        try:
            # Compare last 7 days to previous 7 days
            recent_date = user_data['date'].max()
            week_ago = recent_date - timedelta(days=7)
            two_weeks_ago = recent_date - timedelta(days=14)
            
            recent_data = user_data[user_data['date'] > week_ago]
            previous_data = user_data[
                (user_data['date'] <= week_ago) & (user_data['date'] > two_weeks_ago)
            ]
            
            improvements = {}
            struggles = {}
            
            for metric_type in user_data['metric_type'].unique():
                recent_metric = recent_data[recent_data['metric_type'] == metric_type]
                previous_metric = previous_data[previous_data['metric_type'] == metric_type]
                
                if not recent_metric.empty and not previous_metric.empty:
                    recent_avg = recent_metric['value'].mean()
                    previous_avg = previous_metric['value'].mean()
                    
                    if previous_avg > 0:
                        change_pct = ((recent_avg - previous_avg) / previous_avg) * 100
                        
                        if change_pct > 5:  # 5% improvement threshold
                            improvements[metric_type] = round(change_pct, 1)
                        elif change_pct < -10:  # 10% decline threshold
                            struggles[metric_type] = round(abs(change_pct), 1)
            
            return {
                "has_improvements": len(improvements) > 0,
                "has_struggles": len(struggles) > 0,
                "improvements": improvements,
                "struggles": struggles
            }
            
        except Exception as e:
            logger.error(f"Error analyzing recent progress: {e}")
            return {"has_improvements": False, "has_struggles": False}
    
    def _analyze_behavior_pattern(self, user_data: pd.DataFrame, behavior: str) -> Dict:
        """Analyze current behavior patterns for intervention planning"""
        # This would analyze specific behavior patterns
        # For now, return a basic pattern analysis
        return {
            "description": f"Inconsistent {behavior} with room for improvement",
            "frequency": "3-4 times per week",
            "barriers": ["time_constraints", "motivation_fluctuation"],
            "strengths": ["awareness", "willingness_to_track"]
        }
    
    def _select_intervention_strategy(self, pattern: Dict) -> str:
        """Select the most appropriate intervention strategy"""
        barriers = pattern.get("barriers", [])
        
        if "time_constraints" in barriers:
            return "habit_formation"
        elif "motivation_fluctuation" in barriers:
            return "social_support"
        else:
            return "barrier_removal"
    
    def _define_desired_pattern(self, behavior: str) -> str:
        """Define the desired behavior pattern"""
        patterns = {
            "exercise": "Regular exercise 4-5 times per week with consistent timing",
            "sleep": "Consistent 7-8 hours of sleep with regular bedtime routine",
            "nutrition": "Balanced meals with consistent timing and portion control",
            "hydration": "Adequate water intake throughout the day"
        }
        return patterns.get(behavior, f"Consistent and healthy {behavior} patterns")
    
    def _define_success_metrics(self, behavior: str) -> List[str]:
        """Define success metrics for behavior change"""
        metrics = {
            "exercise": ["workout_frequency", "duration_consistency", "energy_levels"],
            "sleep": ["sleep_duration", "sleep_quality", "morning_energy"],
            "nutrition": ["meal_timing", "portion_control", "energy_stability"],
            "hydration": ["daily_water_intake", "hydration_consistency"]
        }
        return metrics.get(behavior, ["frequency", "consistency", "satisfaction"])
    
    def _assess_difficulty_level(self, pattern: Dict) -> str:
        """Assess the difficulty level of behavior change"""
        barriers = pattern.get("barriers", [])
        
        if len(barriers) > 2:
            return "challenging"
        elif len(barriers) > 1:
            return "moderate"
        else:
            return "manageable"
    
    def _generate_default_messages(self) -> List[CoachingMessage]:
        """Generate default messages when user data is insufficient"""
        return [
            CoachingMessage(
                id=f"default_welcome_{datetime.now().strftime('%Y%m%d_%H%M%S')}",
                coaching_type=CoachingType.MOTIVATIONAL,
                title="Welcome to Your Health Journey! 🌟",
                message="Every great journey begins with a single step. You've taken that step by prioritizing your health. I'm here to support you every step of the way with personalized guidance and encouragement.",
                timing=InterventionTiming.IMMEDIATE,
                priority=3,
                target_metrics=["overall_wellness"],
                actionable_steps=[
                    "Start tracking one health metric that matters to you",
                    "Set a small, achievable goal for this week",
                    "Celebrate every positive choice you make"
                ],
                expected_outcome="Increased motivation to begin health tracking",
                follow_up_days=3,
                personalization_factors=["new_user", "encouragement"]
            )
        ]
    
    async def _get_user_health_data(
        self,
        user_id: int,
        db: Session,
        days: int
    ) -> Optional[pd.DataFrame]:
        """Retrieve user health data for coaching analysis"""
        try:
            end_date = datetime.now()
            start_date = end_date - timedelta(days=days)
            
            health_data = db.query(HealthData).filter(
                HealthData.user_id == user_id,
                HealthData.recorded_at >= start_date,
                HealthData.recorded_at <= end_date
            ).all()
            
            if not health_data:
                return None
            
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
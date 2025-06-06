"""
Achievement Engine

This module provides comprehensive achievement tracking, milestone detection, badge management,
and celebration systems to maintain user motivation and engagement with their health goals.
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
from ..core.models import User, HealthMetricUnified
from .pattern_recognition import PatternRecognizer

logger = logging.getLogger(__name__)

class AchievementType(Enum):
    """Types of achievements"""
    MILESTONE = "milestone"
    STREAK = "streak"
    IMPROVEMENT = "improvement"
    CONSISTENCY = "consistency"
    GOAL_COMPLETION = "goal_completion"
    PERSONAL_BEST = "personal_best"
    CHALLENGE = "challenge"

class BadgeLevel(Enum):
    """Badge difficulty levels"""
    BRONZE = "bronze"
    SILVER = "silver"
    GOLD = "gold"
    PLATINUM = "platinum"
    DIAMOND = "diamond"

class CelebrationLevel(Enum):
    """Celebration intensity levels"""
    MINOR = "minor"
    MODERATE = "moderate"
    MAJOR = "major"
    EPIC = "epic"

@dataclass
class Achievement:
    """Represents a health achievement"""
    id: str
    achievement_type: AchievementType
    title: str
    description: str
    badge_level: BadgeLevel
    celebration_level: CelebrationLevel
    earned_date: datetime
    metric_type: str
    achievement_value: float
    previous_best: Optional[float]
    improvement_percentage: Optional[float]
    streak_days: Optional[int]
    requirements_met: List[str]
    next_milestone: Optional[str]
    sharing_message: str
    motivation_message: str

@dataclass
class Streak:
    """Represents a health streak"""
    id: str
    metric_type: str
    current_count: int
    best_count: int
    start_date: datetime
    last_update: datetime
    target_value: float
    streak_type: str  # daily, weekly, monthly
    is_active: bool
    milestone_reached: List[int]

@dataclass
class Milestone:
    """Represents a health milestone"""
    id: str
    metric_type: str
    milestone_value: float
    milestone_type: str
    achieved_date: Optional[datetime]
    progress_percentage: float
    next_milestone_value: Optional[float]
    celebration_triggered: bool

@dataclass
class CelebrationEvent:
    """Represents a celebration event"""
    id: str
    achievement_id: str
    celebration_type: str
    celebration_level: CelebrationLevel
    trigger_date: datetime
    message: str
    visual_elements: List[str]
    sound_effects: List[str]
    sharing_options: List[str]
    follow_up_actions: List[str]

class AchievementEngine:
    """
    Comprehensive achievement tracking system that detects milestones, manages badges,
    tracks streaks, and triggers celebrations to maintain user motivation.
    """
    
    def __init__(self):
        self.pattern_recognizer = PatternRecognizer()
        
        # Achievement thresholds and configurations
        self.milestone_thresholds = self._initialize_milestone_thresholds()
        self.streak_requirements = self._initialize_streak_requirements()
        self.badge_criteria = self._initialize_badge_criteria()
        self.celebration_configs = self._initialize_celebration_configs()
        
    def _initialize_milestone_thresholds(self) -> Dict[str, List[float]]:
        """Initialize milestone thresholds for different metrics (using HealthKit naming)"""
        return {
            "activity_steps": [1000, 3000, 5000, 8000, 10000, 12000, 15000],
            "sleep_duration": [4.0, 5.0, 6.0, 7.0, 7.5, 8.0, 8.5],
            "nutrition_water": [1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0],
            "body_weight": [1.0, 2.5, 5.0, 7.5, 10.0, 15.0, 20.0],
            "heart_rate_resting": [80, 75, 70, 65, 60, 55, 50],
            "activity_active_energy": [100, 200, 400, 600, 800, 1000, 1200],
            "activity_workouts": [1, 3, 5, 10, 15, 20, 30],
            "consistency_score": [0.3, 0.5, 0.6, 0.7, 0.8, 0.85, 0.9]
        }
    
    def _initialize_streak_requirements(self) -> Dict[str, Dict]:
        """Initialize streak requirements and thresholds"""
        return {
            "daily_steps": {
                "target": 8000,
                "milestones": [3, 7, 14, 30, 60, 90, 180, 365],
                "type": "daily"
            },
            "sleep_consistency": {
                "target": 7.0,
                "milestones": [3, 7, 14, 21, 30, 60, 90],
                "type": "daily"
            },
            "water_intake": {
                "target": 2.5,
                "milestones": [3, 7, 14, 30, 60, 90],
                "type": "daily"
            },
            "workout_frequency": {
                "target": 3,
                "milestones": [2, 4, 8, 12, 24, 48],
                "type": "weekly"
            },
            "weight_tracking": {
                "target": 1,
                "milestones": [7, 14, 30, 60, 90, 180],
                "type": "daily"
            }
        }
    
    def _initialize_badge_criteria(self) -> Dict[BadgeLevel, Dict]:
        """Initialize badge criteria for different levels"""
        return {
            BadgeLevel.BRONZE: {
                "streak_days": 7,
                "improvement_percentage": 10,
                "consistency_score": 0.6,
                "milestone_count": 1
            },
            BadgeLevel.SILVER: {
                "streak_days": 30,
                "improvement_percentage": 25,
                "consistency_score": 0.7,
                "milestone_count": 3
            },
            BadgeLevel.GOLD: {
                "streak_days": 90,
                "improvement_percentage": 50,
                "consistency_score": 0.8,
                "milestone_count": 5
            },
            BadgeLevel.PLATINUM: {
                "streak_days": 180,
                "improvement_percentage": 75,
                "consistency_score": 0.9,
                "milestone_count": 8
            },
            BadgeLevel.DIAMOND: {
                "streak_days": 365,
                "improvement_percentage": 100,
                "consistency_score": 0.95,
                "milestone_count": 10
            }
        }
    
    def _initialize_celebration_configs(self) -> Dict[CelebrationLevel, Dict]:
        """Initialize celebration configurations"""
        return {
            CelebrationLevel.MINOR: {
                "visual_elements": ["confetti", "badge_glow"],
                "sound_effects": ["chime"],
                "duration_seconds": 2,
                "sharing_options": ["internal"]
            },
            CelebrationLevel.MODERATE: {
                "visual_elements": ["fireworks", "badge_animation", "progress_highlight"],
                "sound_effects": ["fanfare", "applause"],
                "duration_seconds": 4,
                "sharing_options": ["internal", "social_media"]
            },
            CelebrationLevel.MAJOR: {
                "visual_elements": ["full_screen_animation", "achievement_showcase", "progress_timeline"],
                "sound_effects": ["victory_theme", "crowd_cheer"],
                "duration_seconds": 6,
                "sharing_options": ["internal", "social_media", "friends"]
            },
            CelebrationLevel.EPIC: {
                "visual_elements": ["epic_animation", "hall_of_fame", "achievement_gallery", "progress_journey"],
                "sound_effects": ["epic_theme", "stadium_roar"],
                "duration_seconds": 10,
                "sharing_options": ["internal", "social_media", "friends", "leaderboard"]
            }
        }
    
    async def detect_achievements(
        self,
        user_id: int,
        db: Session,
        date_range_days: int = 7
    ) -> List[Achievement]:
        """
        Detect new achievements based on recent user activity and progress.
        
        Args:
            user_id: User identifier
            db: Database session
            date_range_days: Number of days to analyze for achievements
            
        Returns:
            List of newly detected achievements
        """
        try:
            logger.info(f"Detecting achievements for user {user_id}")
            
            # Get user health data
            user_data = await self._get_user_health_data(user_id, db, date_range_days)
            if user_data is None or user_data.empty:
                return []
            
            # Get historical data for comparison
            historical_data = await self._get_user_health_data(user_id, db, 90)
            
            achievements = []
            
            # Detect different types of achievements
            milestone_achievements = await self._detect_milestone_achievements(
                user_data, historical_data
            )
            achievements.extend(milestone_achievements)
            
            streak_achievements = await self._detect_streak_achievements(
                user_id, db, user_data
            )
            achievements.extend(streak_achievements)
            
            improvement_achievements = await self._detect_improvement_achievements(
                user_data, historical_data
            )
            achievements.extend(improvement_achievements)
            
            consistency_achievements = await self._detect_consistency_achievements(
                user_data, historical_data
            )
            achievements.extend(consistency_achievements)
            
            personal_best_achievements = await self._detect_personal_best_achievements(
                user_data, historical_data
            )
            achievements.extend(personal_best_achievements)
            
            # If no achievements detected, generate some basic participation achievements
            if not achievements:
                achievements = self._generate_basic_achievements(user_data)
            
            # If still no achievements, use fallback
            if not achievements:
                achievements = self._generate_fallback_achievements()
            
            logger.info(f"Detected {len(achievements)} achievements")
            return achievements
            
        except Exception as e:
            logger.error(f"Error detecting achievements: {e}")
            # Return basic achievements as fallback
            fallback_achievements = self._generate_fallback_achievements()
            logger.info(f"Returning {len(fallback_achievements)} fallback achievements")
            return fallback_achievements
    
    async def _detect_milestone_achievements(
        self,
        user_data: pd.DataFrame,
        historical_data: pd.DataFrame
    ) -> List[Achievement]:
        """Detect milestone achievements"""
        achievements = []
        
        try:
            for metric_type in user_data['metric_type'].unique():
                if metric_type not in self.milestone_thresholds:
                    continue
                
                metric_data = user_data[user_data['metric_type'] == metric_type]
                if metric_data.empty:
                    continue
                
                # Get current best value
                current_best = metric_data['value'].max()
                thresholds = self.milestone_thresholds[metric_type]
                
                # Check which milestones were reached
                for threshold in thresholds:
                    if self._milestone_reached(current_best, threshold, metric_type):
                        # Check if this is a new milestone
                        if not self._was_milestone_previously_achieved(
                            historical_data, metric_type, threshold
                        ):
                            achievement = self._create_milestone_achievement(
                                metric_type, threshold, current_best
                            )
                            achievements.append(achievement)
            
            return achievements
            
        except Exception as e:
            logger.error(f"Error detecting milestone achievements: {e}")
            return []
    
    async def _detect_streak_achievements(
        self,
        user_id: int,
        db: Session,
        user_data: pd.DataFrame
    ) -> List[Achievement]:
        """Detect streak achievements"""
        achievements = []
        
        try:
            # Get current streaks
            current_streaks = await self.get_user_streaks(user_id, db)
            
            for streak in current_streaks:
                if not streak.is_active:
                    continue
                
                # Check if streak reached a new milestone
                streak_config = self.streak_requirements.get(streak.metric_type, {})
                milestones = streak_config.get("milestones", [])
                
                for milestone in milestones:
                    if (streak.current_count >= milestone and 
                        milestone not in streak.milestone_reached):
                        
                        achievement = self._create_streak_achievement(
                            streak, milestone
                        )
                        achievements.append(achievement)
                        
                        # Update streak milestone tracking
                        streak.milestone_reached.append(milestone)
            
            return achievements
            
        except Exception as e:
            logger.error(f"Error detecting streak achievements: {e}")
            return []
    
    async def _detect_improvement_achievements(
        self,
        user_data: pd.DataFrame,
        historical_data: pd.DataFrame
    ) -> List[Achievement]:
        """Detect improvement achievements"""
        achievements = []
        
        try:
            for metric_type in user_data['metric_type'].unique():
                # Calculate improvement over time
                improvement = self._calculate_improvement_percentage(
                    user_data, historical_data, metric_type
                )
                
                if improvement is None:
                    continue
                
                # Check if improvement meets badge criteria
                for badge_level, criteria in self.badge_criteria.items():
                    required_improvement = criteria["improvement_percentage"]
                    
                    if improvement >= required_improvement:
                        achievement = self._create_improvement_achievement(
                            metric_type, improvement, badge_level
                        )
                        achievements.append(achievement)
                        break  # Award highest applicable badge
            
            return achievements
            
        except Exception as e:
            logger.error(f"Error detecting improvement achievements: {e}")
            return []
    
    async def _detect_consistency_achievements(
        self,
        user_data: pd.DataFrame,
        historical_data: pd.DataFrame
    ) -> List[Achievement]:
        """Detect consistency achievements"""
        achievements = []
        
        try:
            # Calculate consistency scores for different metrics
            consistency_scores = await self._calculate_consistency_scores(user_data)
            
            for metric_type, score in consistency_scores.items():
                # Check if consistency meets badge criteria
                for badge_level, criteria in self.badge_criteria.items():
                    required_consistency = criteria["consistency_score"]
                    
                    if score >= required_consistency:
                        achievement = self._create_consistency_achievement(
                            metric_type, score, badge_level
                        )
                        achievements.append(achievement)
                        break  # Award highest applicable badge
            
            return achievements
            
        except Exception as e:
            logger.error(f"Error detecting consistency achievements: {e}")
            return []
    
    async def _detect_personal_best_achievements(
        self,
        user_data: pd.DataFrame,
        historical_data: pd.DataFrame
    ) -> List[Achievement]:
        """Detect personal best achievements"""
        achievements = []
        
        try:
            for metric_type in user_data['metric_type'].unique():
                current_data = user_data[user_data['metric_type'] == metric_type]
                historical_metric_data = historical_data[
                    historical_data['metric_type'] == metric_type
                ]
                
                if current_data.empty or historical_metric_data.empty:
                    continue
                
                current_best = current_data['value'].max()
                historical_best = historical_metric_data['value'].max()
                
                # Check if current best exceeds historical best
                if self._is_personal_best(current_best, historical_best, metric_type):
                    improvement = self._calculate_personal_best_improvement(
                        current_best, historical_best, metric_type
                    )
                    
                    achievement = self._create_personal_best_achievement(
                        metric_type, current_best, historical_best, improvement
                    )
                    achievements.append(achievement)
            
            return achievements
            
        except Exception as e:
            logger.error(f"Error detecting personal best achievements: {e}")
            return []
    
    def _milestone_reached(self, value: float, threshold: float, metric_type: str) -> bool:
        """Check if a milestone was reached"""
        # For metrics where lower is better (like resting heart rate)
        lower_is_better = ["resting_heart_rate", "weight"]
        
        if metric_type in lower_is_better:
            return value <= threshold
        else:
            return value >= threshold
    
    def _was_milestone_previously_achieved(
        self,
        historical_data: pd.DataFrame,
        metric_type: str,
        threshold: float
    ) -> bool:
        """Check if milestone was previously achieved"""
        if historical_data.empty:
            return False
        
        metric_data = historical_data[historical_data['metric_type'] == metric_type]
        if metric_data.empty:
            return False
        
        historical_best = metric_data['value'].max()
        return self._milestone_reached(historical_best, threshold, metric_type)
    
    def _create_milestone_achievement(
        self,
        metric_type: str,
        threshold: float,
        current_value: float
    ) -> Achievement:
        """Create a milestone achievement"""
        
        achievement_id = f"milestone_{metric_type}_{threshold}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        # Determine badge level based on threshold position
        thresholds = self.milestone_thresholds[metric_type]
        threshold_index = thresholds.index(threshold)
        badge_level = self._determine_badge_level_from_index(threshold_index, len(thresholds))
        
        # Determine celebration level
        celebration_level = self._determine_celebration_level(badge_level)
        
        # Generate messages
        title, description = self._generate_milestone_messages(metric_type, threshold)
        sharing_message = self._generate_sharing_message(title, metric_type, threshold)
        motivation_message = self._generate_motivation_message(metric_type, threshold)
        
        return Achievement(
            id=achievement_id,
            achievement_type=AchievementType.MILESTONE,
            title=title,
            description=description,
            badge_level=badge_level,
            celebration_level=celebration_level,
            earned_date=datetime.now(),
            metric_type=metric_type,
            achievement_value=threshold,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=[f"Reached {threshold} {metric_type}"],
            next_milestone=self._get_next_milestone(metric_type, threshold),
            sharing_message=sharing_message,
            motivation_message=motivation_message
        )
    
    def _create_streak_achievement(self, streak: Streak, milestone: int) -> Achievement:
        """Create a streak achievement"""
        
        achievement_id = f"streak_{streak.metric_type}_{milestone}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        # Determine badge level based on streak length
        badge_level = self._determine_badge_level_from_streak(milestone)
        celebration_level = self._determine_celebration_level(badge_level)
        
        # Generate messages
        title = f"{milestone}-Day {streak.metric_type.replace('_', ' ').title()} Streak!"
        description = f"Maintained consistent {streak.metric_type.replace('_', ' ')} for {milestone} consecutive days."
        
        sharing_message = f"Just achieved a {milestone}-day streak in {streak.metric_type.replace('_', ' ')}! 🔥"
        motivation_message = f"Amazing consistency! Keep up the great work with your {streak.metric_type.replace('_', ' ')}."
        
        return Achievement(
            id=achievement_id,
            achievement_type=AchievementType.STREAK,
            title=title,
            description=description,
            badge_level=badge_level,
            celebration_level=celebration_level,
            earned_date=datetime.now(),
            metric_type=streak.metric_type,
            achievement_value=milestone,
            previous_best=streak.best_count,
            improvement_percentage=None,
            streak_days=milestone,
            requirements_met=[f"Maintained {milestone} consecutive days"],
            next_milestone=self._get_next_streak_milestone(streak.metric_type, milestone),
            sharing_message=sharing_message,
            motivation_message=motivation_message
        )
    
    def _create_improvement_achievement(
        self,
        metric_type: str,
        improvement: float,
        badge_level: BadgeLevel
    ) -> Achievement:
        """Create an improvement achievement"""
        
        achievement_id = f"improvement_{metric_type}_{badge_level.value}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        celebration_level = self._determine_celebration_level(badge_level)
        
        title = f"{badge_level.value.title()} Improvement in {metric_type.replace('_', ' ').title()}"
        description = f"Achieved {improvement:.1f}% improvement in {metric_type.replace('_', ' ')} over time."
        
        sharing_message = f"Just earned a {badge_level.value} badge for {improvement:.1f}% improvement in {metric_type.replace('_', ' ')}! 📈"
        motivation_message = f"Incredible progress! Your {improvement:.1f}% improvement shows real dedication."
        
        return Achievement(
            id=achievement_id,
            achievement_type=AchievementType.IMPROVEMENT,
            title=title,
            description=description,
            badge_level=badge_level,
            celebration_level=celebration_level,
            earned_date=datetime.now(),
            metric_type=metric_type,
            achievement_value=improvement,
            previous_best=None,
            improvement_percentage=improvement,
            streak_days=None,
            requirements_met=[f"Improved by {improvement:.1f}%"],
            next_milestone=None,
            sharing_message=sharing_message,
            motivation_message=motivation_message
        )
    
    def _create_consistency_achievement(
        self,
        metric_type: str,
        consistency_score: float,
        badge_level: BadgeLevel
    ) -> Achievement:
        """Create a consistency achievement"""
        
        achievement_id = f"consistency_{metric_type}_{badge_level.value}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        celebration_level = self._determine_celebration_level(badge_level)
        
        title = f"{badge_level.value.title()} Consistency in {metric_type.replace('_', ' ').title()}"
        description = f"Maintained {consistency_score:.1%} consistency in {metric_type.replace('_', ' ')} tracking."
        
        sharing_message = f"Earned a {badge_level.value} badge for {consistency_score:.1%} consistency! 🎯"
        motivation_message = f"Outstanding consistency! Your {consistency_score:.1%} tracking rate is exemplary."
        
        return Achievement(
            id=achievement_id,
            achievement_type=AchievementType.CONSISTENCY,
            title=title,
            description=description,
            badge_level=badge_level,
            celebration_level=celebration_level,
            earned_date=datetime.now(),
            metric_type=metric_type,
            achievement_value=consistency_score,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=[f"Maintained {consistency_score:.1%} consistency"],
            next_milestone=None,
            sharing_message=sharing_message,
            motivation_message=motivation_message
        )
    
    def _create_personal_best_achievement(
        self,
        metric_type: str,
        current_best: float,
        previous_best: float,
        improvement: float
    ) -> Achievement:
        """Create a personal best achievement"""
        
        achievement_id = f"personal_best_{metric_type}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        # Determine badge level based on improvement magnitude
        badge_level = self._determine_badge_level_from_improvement(improvement)
        celebration_level = self._determine_celebration_level(badge_level)
        
        title = f"New Personal Best in {metric_type.replace('_', ' ').title()}!"
        description = f"Achieved new personal best of {current_best:.1f}, improving by {improvement:.1f}%."
        
        sharing_message = f"New personal best! {current_best:.1f} in {metric_type.replace('_', ' ')} 🏆"
        motivation_message = f"Fantastic achievement! You've set a new personal record."
        
        return Achievement(
            id=achievement_id,
            achievement_type=AchievementType.PERSONAL_BEST,
            title=title,
            description=description,
            badge_level=badge_level,
            celebration_level=celebration_level,
            earned_date=datetime.now(),
            metric_type=metric_type,
            achievement_value=current_best,
            previous_best=previous_best,
            improvement_percentage=improvement,
            streak_days=None,
            requirements_met=[f"Exceeded previous best of {previous_best:.1f}"],
            next_milestone=None,
            sharing_message=sharing_message,
            motivation_message=motivation_message
        )
    
    async def get_user_streaks(self, user_id: int, db: Session) -> List[Streak]:
        """Get current user streaks"""
        try:
            # This would typically query a streaks table
            # For now, we'll calculate streaks from health data
            
            user_data = await self._get_user_health_data(user_id, db, 90)
            if user_data is None or user_data.empty:
                return []
            
            streaks = []
            
            for metric_type, config in self.streak_requirements.items():
                streak = await self._calculate_current_streak(
                    user_data, metric_type, config
                )
                if streak:
                    streaks.append(streak)
            
            return streaks
            
        except Exception as e:
            logger.error(f"Error getting user streaks: {e}")
            return []
    
    async def _calculate_current_streak(
        self,
        user_data: pd.DataFrame,
        metric_type: str,
        config: Dict
    ) -> Optional[Streak]:
        """Calculate current streak for a metric"""
        try:
            # Filter data for this metric type
            metric_data = user_data[user_data['metric_type'] == metric_type]
            if metric_data.empty:
                return None
            
            # Sort by date
            metric_data = metric_data.sort_values('date')
            target_value = config["target"]
            
            # Calculate streak
            current_streak = 0
            best_streak = 0
            streak_start = None
            last_date = None
            
            for _, row in metric_data.iterrows():
                if row['value'] >= target_value:
                    if current_streak == 0:
                        streak_start = row['date']
                    current_streak += 1
                    best_streak = max(best_streak, current_streak)
                    last_date = row['date']
                else:
                    current_streak = 0
                    streak_start = None
            
            # Check if streak is still active (within last 2 days)
            is_active = (last_date and 
                        (datetime.now().date() - last_date).days <= 2)
            
            streak_id = f"streak_{metric_type}_{user_data['user_id'].iloc[0] if 'user_id' in user_data.columns else 'unknown'}"
            
            return Streak(
                id=streak_id,
                metric_type=metric_type,
                current_count=current_streak if is_active else 0,
                best_count=best_streak,
                start_date=streak_start or datetime.now(),
                last_update=last_date or datetime.now(),
                target_value=target_value,
                streak_type=config["type"],
                is_active=is_active,
                milestone_reached=[]
            )
            
        except Exception as e:
            logger.error(f"Error calculating streak for {metric_type}: {e}")
            return None
    
    async def create_celebration_event(
        self,
        achievement: Achievement
    ) -> CelebrationEvent:
        """Create a celebration event for an achievement"""
        try:
            celebration_config = self.celebration_configs[achievement.celebration_level]
            
            celebration_id = f"celebration_{achievement.id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
            
            # Generate celebration message
            celebration_message = self._generate_celebration_message(achievement)
            
            # Determine follow-up actions
            follow_up_actions = self._generate_follow_up_actions(achievement)
            
            return CelebrationEvent(
                id=celebration_id,
                achievement_id=achievement.id,
                celebration_type=achievement.achievement_type.value,
                celebration_level=achievement.celebration_level,
                trigger_date=datetime.now(),
                message=celebration_message,
                visual_elements=celebration_config["visual_elements"],
                sound_effects=celebration_config["sound_effects"],
                sharing_options=celebration_config["sharing_options"],
                follow_up_actions=follow_up_actions
            )
            
        except Exception as e:
            logger.error(f"Error creating celebration event: {e}")
            return None
    
    def _determine_badge_level_from_index(self, index: int, total: int) -> BadgeLevel:
        """Determine badge level based on milestone index"""
        percentage = (index + 1) / total
        
        if percentage <= 0.2:
            return BadgeLevel.BRONZE
        elif percentage <= 0.4:
            return BadgeLevel.SILVER
        elif percentage <= 0.6:
            return BadgeLevel.GOLD
        elif percentage <= 0.8:
            return BadgeLevel.PLATINUM
        else:
            return BadgeLevel.DIAMOND
    
    def _determine_badge_level_from_streak(self, streak_days: int) -> BadgeLevel:
        """Determine badge level based on streak length"""
        if streak_days >= 365:
            return BadgeLevel.DIAMOND
        elif streak_days >= 180:
            return BadgeLevel.PLATINUM
        elif streak_days >= 90:
            return BadgeLevel.GOLD
        elif streak_days >= 30:
            return BadgeLevel.SILVER
        else:
            return BadgeLevel.BRONZE
    
    def _determine_badge_level_from_improvement(self, improvement: float) -> BadgeLevel:
        """Determine badge level based on improvement percentage"""
        if improvement >= 100:
            return BadgeLevel.DIAMOND
        elif improvement >= 75:
            return BadgeLevel.PLATINUM
        elif improvement >= 50:
            return BadgeLevel.GOLD
        elif improvement >= 25:
            return BadgeLevel.SILVER
        else:
            return BadgeLevel.BRONZE
    
    def _determine_celebration_level(self, badge_level: BadgeLevel) -> CelebrationLevel:
        """Determine celebration level based on badge level"""
        mapping = {
            BadgeLevel.BRONZE: CelebrationLevel.MINOR,
            BadgeLevel.SILVER: CelebrationLevel.MODERATE,
            BadgeLevel.GOLD: CelebrationLevel.MAJOR,
            BadgeLevel.PLATINUM: CelebrationLevel.MAJOR,
            BadgeLevel.DIAMOND: CelebrationLevel.EPIC
        }
        return mapping.get(badge_level, CelebrationLevel.MINOR)
    
    def _generate_milestone_messages(self, metric_type: str, threshold: float) -> Tuple[str, str]:
        """Generate title and description for milestone achievements"""
        
        titles = {
            "steps": f"{threshold:,.0f} Steps Milestone!",
            "sleep_duration": f"{threshold:.1f} Hours Sleep Goal!",
            "water_intake": f"{threshold:.1f}L Hydration Target!",
            "weight_loss": f"{threshold:.1f}kg Weight Loss!",
            "resting_heart_rate": f"{threshold:.0f} BPM Heart Rate!"
        }
        
        descriptions = {
            "steps": f"Reached the {threshold:,.0f} daily steps milestone! Your cardiovascular health is improving.",
            "sleep_duration": f"Achieved {threshold:.1f} hours of quality sleep! Your recovery is optimized.",
            "water_intake": f"Hit your {threshold:.1f}L daily hydration goal! Your body is well-hydrated.",
            "weight_loss": f"Lost {threshold:.1f}kg towards your health goals! Your dedication is paying off.",
            "resting_heart_rate": f"Lowered resting heart rate to {threshold:.0f} BPM! Your fitness is improving."
        }
        
        title = titles.get(metric_type, f"{metric_type.replace('_', ' ').title()} Milestone!")
        description = descriptions.get(metric_type, f"Achieved milestone in {metric_type.replace('_', ' ')}!")
        
        return title, description
    
    def _generate_sharing_message(self, title: str, metric_type: str, threshold: float) -> str:
        """Generate sharing message for social media"""
        emojis = {
            "steps": "👟",
            "sleep_duration": "😴",
            "water_intake": "💧",
            "weight_loss": "⚖️",
            "resting_heart_rate": "❤️"
        }
        
        emoji = emojis.get(metric_type, "🏆")
        return f"{title} {emoji} #HealthGoals #Fitness #Wellness"
    
    def _generate_motivation_message(self, metric_type: str, threshold: float) -> str:
        """Generate motivational message"""
        
        messages = {
            "steps": "Every step counts towards a healthier you! Keep moving forward.",
            "sleep_duration": "Quality sleep is the foundation of good health. Sweet dreams!",
            "water_intake": "Staying hydrated keeps your body functioning at its best!",
            "weight_loss": "Your commitment to health is inspiring. Keep up the great work!",
            "resting_heart_rate": "Your heart is getting stronger every day. Amazing progress!"
        }
        
        return messages.get(metric_type, "Fantastic achievement! You're on the path to better health.")
    
    def _get_next_milestone(self, metric_type: str, current_threshold: float) -> Optional[str]:
        """Get the next milestone for a metric"""
        thresholds = self.milestone_thresholds.get(metric_type, [])
        
        for threshold in thresholds:
            if threshold > current_threshold:
                return f"Next milestone: {threshold} {metric_type}"
        
        return "You've reached the highest milestone!"
    
    def _get_next_streak_milestone(self, metric_type: str, current_milestone: int) -> Optional[str]:
        """Get the next streak milestone"""
        config = self.streak_requirements.get(metric_type, {})
        milestones = config.get("milestones", [])
        
        for milestone in milestones:
            if milestone > current_milestone:
                return f"Next streak milestone: {milestone} days"
        
        return "You've reached the ultimate streak milestone!"
    
    def _calculate_improvement_percentage(
        self,
        current_data: pd.DataFrame,
        historical_data: pd.DataFrame,
        metric_type: str
    ) -> Optional[float]:
        """Calculate improvement percentage for a metric"""
        try:
            current_metric = current_data[current_data['metric_type'] == metric_type]
            historical_metric = historical_data[historical_data['metric_type'] == metric_type]
            
            if current_metric.empty or historical_metric.empty:
                return None
            
            current_avg = current_metric['value'].mean()
            historical_avg = historical_metric['value'].mean()
            
            if historical_avg == 0:
                return None
            
            improvement = ((current_avg - historical_avg) / historical_avg) * 100
            
            # For metrics where lower is better, invert the improvement
            lower_is_better = ["resting_heart_rate", "weight"]
            if metric_type in lower_is_better:
                improvement = -improvement
            
            return max(0, improvement)  # Only positive improvements
            
        except Exception as e:
            logger.error(f"Error calculating improvement for {metric_type}: {e}")
            return None
    
    async def _calculate_consistency_scores(self, user_data: pd.DataFrame) -> Dict[str, float]:
        """Calculate consistency scores for different metrics"""
        try:
            consistency_scores = {}
            
            for metric_type in user_data['metric_type'].unique():
                metric_data = user_data[user_data['metric_type'] == metric_type]
                
                # Calculate consistency as percentage of days with data
                total_days = (user_data['date'].max() - user_data['date'].min()).days + 1
                days_with_data = len(metric_data['date'].unique())
                
                consistency_score = days_with_data / total_days if total_days > 0 else 0
                consistency_scores[metric_type] = consistency_score
            
            return consistency_scores
            
        except Exception as e:
            logger.error(f"Error calculating consistency scores: {e}")
            return {}
    
    def _is_personal_best(self, current_value: float, historical_best: float, metric_type: str) -> bool:
        """Check if current value is a personal best"""
        lower_is_better = ["resting_heart_rate", "weight"]
        
        if metric_type in lower_is_better:
            return current_value < historical_best
        else:
            return current_value > historical_best
    
    def _calculate_personal_best_improvement(
        self,
        current_best: float,
        historical_best: float,
        metric_type: str
    ) -> float:
        """Calculate improvement percentage for personal best"""
        if historical_best == 0:
            return 0
        
        improvement = abs((current_best - historical_best) / historical_best) * 100
        return improvement
    
    def _generate_celebration_message(self, achievement: Achievement) -> str:
        """Generate celebration message"""
        celebration_messages = {
            AchievementType.MILESTONE: f"🎉 Congratulations! You've reached an important milestone in your health journey!",
            AchievementType.STREAK: f"🔥 Amazing streak! Your consistency is truly inspiring!",
            AchievementType.IMPROVEMENT: f"📈 Incredible improvement! Your hard work is paying off!",
            AchievementType.CONSISTENCY: f"🎯 Outstanding consistency! You're building great habits!",
            AchievementType.PERSONAL_BEST: f"🏆 New personal record! You've outdone yourself!"
        }
        
        return celebration_messages.get(achievement.achievement_type, "🎉 Congratulations on your achievement!")
    
    def _generate_follow_up_actions(self, achievement: Achievement) -> List[str]:
        """Generate follow-up actions for an achievement"""
        base_actions = [
            "Share your achievement with friends",
            "Set a new goal to maintain momentum",
            "Review your progress in the insights dashboard"
        ]
        
        specific_actions = {
            AchievementType.MILESTONE: [
                "Explore the next milestone target",
                "Analyze what helped you reach this milestone"
            ],
            AchievementType.STREAK: [
                "Keep the streak alive with tomorrow's activity",
                "Share your streak strategy with the community"
            ],
            AchievementType.IMPROVEMENT: [
                "Identify the key factors in your improvement",
                "Set an even more ambitious goal"
            ]
        }
        
        actions = base_actions.copy()
        actions.extend(specific_actions.get(achievement.achievement_type, []))
        
        return actions
    
    async def _get_user_health_data(
        self,
        user_id: int,
        db: Session,
        days: int
    ) -> Optional[pd.DataFrame]:
        """Retrieve user health data for analysis"""
        try:
            end_date = datetime.now()
            start_date = end_date - timedelta(days=days)
            
            health_data = db.query(HealthMetricUnified).filter(
                HealthMetricUnified.user_id == user_id,
                HealthMetricUnified.timestamp >= start_date,
                HealthMetricUnified.timestamp <= end_date
            ).all()
            
            if not health_data:
                return None
            
            data_list = []
            for record in health_data:
                data_list.append({
                    'date': record.timestamp.date(),
                    'metric_type': record.metric_type,
                    'value': float(record.value),  # Convert Decimal to float for proper pandas/numpy processing
                    'unit': record.unit,
                    'source': record.data_source
                })
            
            df = pd.DataFrame(data_list)
            
            # Ensure numeric columns are properly typed
            if not df.empty:
                df['value'] = pd.to_numeric(df['value'], errors='coerce')
            
            return df
            
        except Exception as e:
            logger.error(f"Error retrieving user health data: {e}")
            return None
    
    def _generate_basic_achievements(self, user_data: pd.DataFrame) -> List[Achievement]:
        """Generate basic participation achievements when complex detection fails"""
        achievements = []
        
        try:
            # Data tracking achievement
            unique_days = user_data['date'].nunique() if 'date' in user_data.columns else len(user_data)
            if unique_days >= 1:
                achievements.append(Achievement(
                    id=f"data_tracker_{datetime.now().strftime('%Y%m%d')}",
                    achievement_type=AchievementType.CONSISTENCY,
                    title="Data Tracker! 📊",
                    description=f"You've been tracking your health data for {unique_days} day{'s' if unique_days > 1 else ''}!",
                    badge_level=BadgeLevel.BRONZE,
                    celebration_level=CelebrationLevel.MINOR,
                    earned_date=datetime.now(),
                    metric_type="data_tracking",
                    achievement_value=float(unique_days),
                    previous_best=None,
                    improvement_percentage=None,
                    streak_days=unique_days,
                    requirements_met=["data_tracking"],
                    next_milestone="Track for 7 days to earn Silver badge",
                    sharing_message=f"I've been tracking my health for {unique_days} day{'s' if unique_days > 1 else ''}! 📊",
                    motivation_message="Keep tracking to unlock more achievements!"
                ))
            
            # Activity achievement (if steps data exists)
            steps_data = user_data[user_data['metric_type'] == 'activity_steps']
            if not steps_data.empty:
                total_steps = steps_data['value'].sum()
                achievements.append(Achievement(
                    id=f"step_starter_{datetime.now().strftime('%Y%m%d')}",
                    achievement_type=AchievementType.MILESTONE,
                    title="Step Starter! 👟",
                    description=f"You've taken {total_steps:,.0f} steps! Every step counts towards better health.",
                    badge_level=BadgeLevel.BRONZE,
                    celebration_level=CelebrationLevel.MINOR,
                    earned_date=datetime.now(),
                    metric_type="activity_steps",
                    achievement_value=total_steps,
                    previous_best=None,
                    improvement_percentage=None,
                    streak_days=None,
                    requirements_met=["step_tracking"],
                    next_milestone="Reach 5,000 steps in a day for next milestone",
                    sharing_message=f"I've taken {total_steps:,.0f} steps on my health journey! 👟",
                    motivation_message="Keep moving forward, one step at a time!"
                ))
            
            return achievements
            
        except Exception as e:
            logger.error(f"Error generating basic achievements: {e}")
            return []
    
    def _generate_fallback_achievements(self) -> List[Achievement]:
        """Generate mix of completed and aspirational achievements for user engagement"""
        current_time = datetime.now()
        achievements = []
        
        # Welcome achievement (COMPLETED)
        achievements.append(Achievement(
            id=f"health_journey_{current_time.strftime('%Y%m%d')}",
            achievement_type=AchievementType.MILESTONE,
            title="Health Journey Begun! 🌟",
            description="You've started your health tracking journey! This is the first step towards a healthier you.",
            badge_level=BadgeLevel.BRONZE,
            celebration_level=CelebrationLevel.MINOR,
            earned_date=current_time,
            metric_type="general_health",
            achievement_value=1.0,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=["app_usage"],
            next_milestone="Continue tracking to unlock more achievements",
            sharing_message="I've started my health journey! 🌟",
            motivation_message="Every journey begins with a single step. You've taken yours!"
        ))
        
        # Data explorer achievement
        achievements.append(Achievement(
            id=f"data_explorer_{current_time.strftime('%Y%m%d')}",
            achievement_type=AchievementType.CONSISTENCY,
            title="Data Explorer! 📊",
            description="You're exploring your health data! Knowledge is the foundation of improvement.",
            badge_level=BadgeLevel.BRONZE,
            celebration_level=CelebrationLevel.MINOR,
            earned_date=current_time,
            metric_type="data_exploration",
            achievement_value=1.0,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=["dashboard_view"],
            next_milestone="View insights for 3 days to earn Silver badge",
            sharing_message="I'm exploring my health data! 📊",
            motivation_message="Understanding your data is the key to lasting health improvements!"
        ))
        
        # Insight seeker achievement
        achievements.append(Achievement(
            id=f"insight_seeker_{current_time.strftime('%Y%m%d')}",
            achievement_type=AchievementType.MILESTONE,
            title="Insight Seeker! 🔍",
            description="You're actively seeking health insights! This curiosity will fuel your success.",
            badge_level=BadgeLevel.BRONZE,
            celebration_level=CelebrationLevel.MINOR,
            earned_date=current_time,
            metric_type="insights",
            achievement_value=1.0,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=["insights_access"],
            next_milestone="Access insights daily for a week to unlock Gold badge",
            sharing_message="I'm seeking health insights! 🔍",
            motivation_message="Your curiosity about your health will lead to amazing discoveries!"
        ))
        
        # Goal setter achievement
        achievements.append(Achievement(
            id=f"goal_setter_{current_time.strftime('%Y%m%d')}",
            achievement_type=AchievementType.MILESTONE,
            title="Goal Setter! 🎯",
            description="You're setting health goals! Having clear targets is essential for success.",
            badge_level=BadgeLevel.BRONZE,
            celebration_level=CelebrationLevel.MINOR,
            earned_date=current_time,
            metric_type="goals",
            achievement_value=1.0,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=["goal_access"],
            next_milestone="Complete your first goal to earn Silver badge",
            sharing_message="I'm setting health goals! 🎯",
            motivation_message="Clear goals are the roadmap to your healthiest self!"
        ))
        
        # Coach listener achievement
        achievements.append(Achievement(
            id=f"coach_listener_{current_time.strftime('%Y%m%d')}",
            achievement_type=AchievementType.CONSISTENCY,
            title="Coach Listener! 🧠",
            description="You're engaging with your health coach! Getting guidance is a smart strategy.",
            badge_level=BadgeLevel.BRONZE,
            celebration_level=CelebrationLevel.MINOR,
            earned_date=current_time,
            metric_type="coaching",
            achievement_value=1.0,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=["coach_access"],
            next_milestone="Follow coach recommendations to unlock Silver badge",
            sharing_message="I'm listening to my health coach! 🧠",
            motivation_message="Great mentors accelerate your journey to better health!"
        ))
        
        # ASPIRATIONAL ACHIEVEMENTS (Not Yet Completed)
        
        # Daily Step Goal (IN PROGRESS)
        achievements.append(Achievement(
            id=f"daily_10k_steps_{current_time.strftime('%Y%m%d')}",
            achievement_type=AchievementType.MILESTONE,
            title="Daily Step Master 👟",
            description="Reach 10,000 steps in a single day. You're currently making great progress!",
            badge_level=BadgeLevel.SILVER,
            celebration_level=CelebrationLevel.MODERATE,
            earned_date=None,  # NOT COMPLETED
            metric_type="activity_steps",
            achievement_value=10000.0,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=[],
            next_milestone="Keep walking! You're on your way to 10,000 steps",
            sharing_message="I'm working toward my 10,000 daily steps goal! 👟",
            motivation_message="Every step counts! You're building strength and endurance."
        ))
        
        # Weekly Consistency (IN PROGRESS)
        achievements.append(Achievement(
            id=f"weekly_consistency_{current_time.strftime('%Y%m%d')}",
            achievement_type=AchievementType.STREAK,
            title="Weekly Warrior 📅",
            description="Track your health data for 7 consecutive days. Consistency is key to success!",
            badge_level=BadgeLevel.SILVER,
            celebration_level=CelebrationLevel.MODERATE,
            earned_date=None,  # NOT COMPLETED
            metric_type="data_tracking",
            achievement_value=7.0,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=[],
            next_milestone="Keep tracking daily to reach 7 days in a row",
            sharing_message="I'm building a 7-day health tracking streak! 📅",
            motivation_message="Consistency creates lasting habits. You're building something amazing!"
        ))
        
        # Sleep Quality Goal (IN PROGRESS)
        achievements.append(Achievement(
            id=f"sleep_quality_{current_time.strftime('%Y%m%d')}",
            achievement_type=AchievementType.MILESTONE,
            title="Sleep Champion 😴",
            description="Get 8 hours of quality sleep in a single night. Rest is crucial for recovery!",
            badge_level=BadgeLevel.GOLD,
            celebration_level=CelebrationLevel.MAJOR,
            earned_date=None,  # NOT COMPLETED
            metric_type="sleep_duration",
            achievement_value=8.0,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=[],
            next_milestone="Aim for 8 hours of sleep tonight",
            sharing_message="I'm working toward 8 hours of quality sleep! 😴",
            motivation_message="Quality sleep is the foundation of good health. Prioritize your rest!"
        ))
        
        # Fitness Enthusiast (IN PROGRESS)
        achievements.append(Achievement(
            id=f"fitness_enthusiast_{current_time.strftime('%Y%m%d')}",
            achievement_type=AchievementType.MILESTONE,
            title="Fitness Enthusiast 💪",
            description="Complete 3 workouts in a week. Building strength and endurance takes dedication!",
            badge_level=BadgeLevel.GOLD,
            celebration_level=CelebrationLevel.MAJOR,
            earned_date=None,  # NOT COMPLETED
            metric_type="activity_workouts",
            achievement_value=3.0,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=[],
            next_milestone="Complete your next workout to make progress",
            sharing_message="I'm working toward 3 workouts this week! 💪",
            motivation_message="Every workout makes you stronger. Your future self will thank you!"
        ))
        
        return achievements
"""
AI Insights API Endpoints

This module provides API endpoints for AI-powered health insights, including
health scores, personalized recommendations, anomaly detection, and pattern analysis.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
import logging

from backend.core.database import get_db
from backend.api.deps import get_current_user
from backend.core.models import User, HealthMetricUnified
# Remove problematic module-level AI imports that contaminate FastAPI with numpy
# from backend.ai.health_insights_engine import health_insights_engine, HealthInsight, HealthScore
from pydantic import BaseModel
# from backend.ai.goal_optimizer import GoalOptimizer, GoalDifficulty
# from backend.ai.achievement_engine import AchievementEngine, Achievement, AchievementType, BadgeLevel, CelebrationLevel
# from backend.ai.health_coach import HealthCoach
# from backend.ai.recommendation_engine import RecommendationEngine
# from backend.ai.anomaly_detector import AnomalyDetector
# from backend.ai.pattern_recognition import PatternRecognizer

logger = logging.getLogger(__name__)

router = APIRouter()

# Remove global AI engine initialization to prevent numpy contamination
# Initialize AI engines
# goal_optimizer = GoalOptimizer()
# achievement_engine = AchievementEngine()
# health_coach = HealthCoach()

@router.get("/test")
async def test_ai_endpoint():
    """Simple test endpoint to verify AI router is working"""
    return {
        "message": "AI endpoints are working!",
        "timestamp": datetime.utcnow().isoformat(),
        "endpoints_available": [
            "/ai/health-score",
            "/ai/insights", 
            "/ai/goals/recommendations",
            "/ai/achievements",
            "/ai/coaching/messages"
        ]
    }

@router.get("/test-lazy-import")
async def test_lazy_import():
    """Test endpoint to verify lazy imports work without numpy contamination"""
    try:
        # Test lazy import of one AI module
        from backend.ai.health_insights_engine import health_insights_engine
        
        # Test if the import was successful
        engine_info = {
            "engine_loaded": True,
            "engine_type": str(type(health_insights_engine)),
            "has_calculate_method": hasattr(health_insights_engine, 'calculate_health_score'),
            "has_insights_method": hasattr(health_insights_engine, 'generate_comprehensive_insights')
        }
        
        return {
            "status": "success",
            "message": "Lazy import test successful - no numpy contamination detected",
            "timestamp": datetime.utcnow().isoformat(),
            "engine_info": engine_info,
            "test_passed": True
        }
        
    except Exception as e:
        return {
            "status": "error", 
            "message": f"Lazy import test failed: {str(e)}",
            "timestamp": datetime.utcnow().isoformat(),
            "test_passed": False,
            "error_type": type(e).__name__
    }

# Pydantic models for API responses
class HealthInsightResponse(BaseModel):
    id: str
    insight_type: str
    priority: str
    title: str
    description: str
    data_sources: List[str]
    metrics_involved: List[str]
    confidence_score: float
    actionable_recommendations: List[str]
    supporting_data: Dict[str, Any]
    created_at: datetime
    expires_at: Optional[datetime] = None

    class Config:
        from_attributes = True


class HealthScoreResponse(BaseModel):
    overall_score: float
    activity_score: float
    sleep_score: float
    nutrition_score: float
    heart_health_score: float
    consistency_score: float
    trend_score: float
    last_updated: datetime

    class Config:
        from_attributes = True


class InsightsSummaryResponse(BaseModel):
    total_insights: int
    high_priority_count: int
    medium_priority_count: int
    low_priority_count: int
    categories: Dict[str, int]
    latest_insights: List[HealthInsightResponse]


class RecommendationResponse(BaseModel):
    category: str
    title: str
    description: str
    metrics: List[str]
    confidence: float
    priority: str
    actions: List[str]
    expected_benefit: str
    timeframe: str


class AnomalyResponse(BaseModel):
    metric: str
    date: str
    value: float
    severity: float
    confidence: float
    type: str
    description: str
    recommendations: List[str]


@router.get("/health-score", response_model=HealthScoreResponse)
async def get_health_score(
    days_back: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get comprehensive health score for the current user
    
    Args:
        days_back: Number of days of historical data to analyze
        current_user: Current authenticated user
        db: Database session
        
    Returns:
        HealthScoreResponse with component scores
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_insights_engine import health_insights_engine
        
        health_score = health_insights_engine.calculate_health_score(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        if not health_score:
            raise HTTPException(
                status_code=404,
                detail="Insufficient health data to calculate score"
            )
        
        return HealthScoreResponse(
            overall_score=health_score.overall_score,
            activity_score=health_score.activity_score,
            sleep_score=health_score.sleep_score,
            nutrition_score=health_score.nutrition_score,
            heart_health_score=health_score.heart_health_score,
            consistency_score=health_score.consistency_score,
            trend_score=health_score.trend_score,
            last_updated=health_score.last_updated
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error calculating health score for user {current_user.id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Error calculating health score")


@router.get("/insights", response_model=List[HealthInsightResponse])
async def get_health_insights(
    days_back: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    insight_type: Optional[str] = Query(None, description="Filter by insight type"),
    priority: Optional[str] = Query(None, description="Filter by priority level"),
    limit: int = Query(20, ge=1, le=100, description="Maximum number of insights to return"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get AI-generated health insights for the current user
    
    Args:
        days_back: Number of days of historical data to analyze
        insight_type: Optional filter by insight type
        priority: Optional filter by priority level
        limit: Maximum number of insights to return
        current_user: Current authenticated user
        db: Database session
        
    Returns:
        List of health insights
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_insights_engine import health_insights_engine
        
        insights = health_insights_engine.generate_comprehensive_insights(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        # Apply filters
        if insight_type:
            insights = [i for i in insights if i.insight_type.value == insight_type]
        
        if priority:
            insights = [i for i in insights if i.priority.value == priority]
        
        # Limit results
        insights = insights[:limit]
        
        # Convert to response models
        response_insights = []
        for insight in insights:
            response_insights.append(HealthInsightResponse(
                id=insight.id,
                insight_type=insight.insight_type.value,
                priority=insight.priority.value,
                title=insight.title,
                description=insight.description,
                data_sources=insight.data_sources,
                metrics_involved=insight.metrics_involved,
                confidence_score=insight.confidence_score,
                actionable_recommendations=insight.actionable_recommendations,
                supporting_data=insight.supporting_data,
                created_at=insight.created_at,
                expires_at=insight.expires_at
            ))
        
        return response_insights
        
    except Exception as e:
        logger.error(f"Error generating insights for user {current_user.id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Error generating health insights")


@router.get("/insights/summary", response_model=InsightsSummaryResponse)
async def get_insights_summary(
    days_back: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get summary of health insights for dashboard display
    
    Args:
        days_back: Number of days of historical data to analyze
        current_user: Current authenticated user
        db: Database session
        
    Returns:
        Summary of insights with counts and latest insights
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_insights_engine import health_insights_engine
        
        insights = health_insights_engine.generate_comprehensive_insights(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        # Count by priority
        priority_counts = {
            'high': 0,
            'medium': 0,
            'low': 0,
            'critical': 0
        }
        
        # Count by category
        category_counts = {}
        for insight in insights:
            priority = insight.priority.value if hasattr(insight.priority, 'value') else str(insight.priority)
            if priority in priority_counts:
                priority_counts[priority] += 1
                
            insight_type = insight.insight_type.value if hasattr(insight.insight_type, 'value') else str(insight.insight_type)
            category_counts[insight_type] = category_counts.get(insight_type, 0) + 1
        
        # Get latest insights (top 5)
        latest_insights = []
        for insight in insights[:5]:
            latest_insights.append(HealthInsightResponse(
                id=insight.id,
                insight_type=insight.insight_type.value if hasattr(insight.insight_type, 'value') else str(insight.insight_type),
                priority=insight.priority.value if hasattr(insight.priority, 'value') else str(insight.priority),
                title=insight.title,
                description=insight.description,
                data_sources=insight.data_sources,
                metrics_involved=insight.metrics_involved,
                confidence_score=insight.confidence_score,
                actionable_recommendations=insight.actionable_recommendations,
                supporting_data=insight.supporting_data,
                created_at=insight.created_at,
                expires_at=insight.expires_at
            ))
        
        return InsightsSummaryResponse(
            total_insights=len(insights),
            high_priority_count=priority_counts['high'],
            medium_priority_count=priority_counts['medium'],
            low_priority_count=priority_counts['low'],
            categories=category_counts,
            latest_insights=latest_insights
        )
        
    except Exception as e:
        logger.error(f"Error generating insights summary for user {current_user.id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Error generating insights summary")


@router.get("/recommendations", response_model=List[RecommendationResponse])
async def get_recommendations(
    days_back: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    category: Optional[str] = Query(None, description="Filter by recommendation category"),
    limit: int = Query(10, ge=1, le=50, description="Maximum number of recommendations"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get personalized health recommendations
    
    Args:
        days_back: Number of days of historical data to analyze
        category: Optional filter by recommendation category
        limit: Maximum number of recommendations to return
        current_user: Current authenticated user
        db: Database session
        
    Returns:
        List of personalized recommendations
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_insights_engine import health_insights_engine
        from backend.ai.recommendation_engine import RecommendationEngine
        
        health_data = health_insights_engine._get_user_health_data(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        if health_data.empty:
            raise HTTPException(
                status_code=404,
                detail="No health data found for recommendations"
            )
        
        # Generate recommendations
        rec_engine = RecommendationEngine()
        recommendations = rec_engine.generate_recommendations(health_data)
        
        # Apply filters
        if category:
            recommendations = [r for r in recommendations if r['category'] == category]
        
        # Limit results
        recommendations = recommendations[:limit]
        
        # Convert to response models
        response_recs = []
        for rec in recommendations:
            response_recs.append(RecommendationResponse(
                category=rec['category'],
                title=rec['title'],
                description=rec['description'],
                metrics=rec['metrics'],
                confidence=rec['confidence'],
                priority=rec['priority'],
                actions=rec['actions'],
                expected_benefit=rec['expected_benefit'],
                timeframe=rec['timeframe']
            ))
        
        return response_recs
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error generating recommendations for user {current_user.id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Error generating recommendations")


@router.get("/anomalies", response_model=List[AnomalyResponse])
async def get_anomalies(
    days_back: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    metric: Optional[str] = Query(None, description="Filter by specific metric"),
    min_severity: float = Query(0.0, ge=0.0, le=1.0, description="Minimum severity threshold"),
    limit: int = Query(20, ge=1, le=100, description="Maximum number of anomalies"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get detected anomalies in health data
    
    Args:
        days_back: Number of days of historical data to analyze
        metric: Optional filter by specific metric
        min_severity: Minimum severity threshold for anomalies
        limit: Maximum number of anomalies to return
        current_user: Current authenticated user
        db: Database session
        
    Returns:
        List of detected anomalies
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_insights_engine import health_insights_engine
        from backend.ai.anomaly_detector import AnomalyDetector
        
        health_data = health_insights_engine._get_user_health_data(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        if health_data.empty:
            raise HTTPException(
                status_code=404,
                detail="No health data found for anomaly detection"
            )
        
        # Detect anomalies
        anomaly_detector = AnomalyDetector()
        anomalies = anomaly_detector.detect_anomalies(health_data)
        
        # Apply filters
        if metric:
            anomalies = [a for a in anomalies if a['metric'] == metric]
        
        if min_severity > 0:
            anomalies = [a for a in anomalies if a['severity'] >= min_severity]
        
        # Limit results
        anomalies = anomalies[:limit]
        
        # Convert to response models
        response_anomalies = []
        for anomaly in anomalies:
            response_anomalies.append(AnomalyResponse(
                metric=anomaly['metric'],
                date=str(anomaly['date']),
                value=anomaly['value'],
                severity=anomaly['severity'],
                confidence=anomaly['confidence'],
                type=anomaly['type'],
                description=anomaly['description'],
                recommendations=anomaly['recommendations']
            ))
        
        return response_anomalies
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error detecting anomalies for user {current_user.id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Error detecting anomalies")


@router.get("/patterns")
async def get_patterns(
    days_back: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    pattern_type: Optional[str] = Query(None, description="Filter by pattern type"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get identified patterns in health data
    
    Args:
        days_back: Number of days of historical data to analyze
        pattern_type: Optional filter by pattern type
        current_user: Current authenticated user
        db: Database session
        
    Returns:
        List of identified patterns
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_insights_engine import health_insights_engine
        from backend.ai.pattern_recognition import PatternRecognizer
        
        health_data = health_insights_engine._get_user_health_data(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        if health_data.empty:
            raise HTTPException(
                status_code=404,
                detail="No health data found for pattern analysis"
            )
        
        # Identify patterns
        pattern_recognizer = PatternRecognizer()
        patterns = pattern_recognizer.identify_patterns(health_data)
        
        # Apply filters
        if pattern_type:
            patterns = [p for p in patterns if p['type'] == pattern_type]
        
        return patterns
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error identifying patterns for user {current_user.id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Error identifying patterns")


@router.get("/trends")
async def get_trends(
    days_back: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    metric: Optional[str] = Query(None, description="Filter by specific metric"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get trend analysis for health metrics
    
    Args:
        days_back: Number of days of historical data to analyze
        metric: Optional filter by specific metric
        current_user: Current authenticated user
        db: Database session
        
    Returns:
        List of trend analyses
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_insights_engine import health_insights_engine
        from backend.ai.pattern_recognition import PatternRecognizer
        
        health_data = health_insights_engine._get_user_health_data(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        if health_data.empty:
            raise HTTPException(
                status_code=404,
                detail="No health data found for trend analysis"
            )
        
        # Analyze trends
        pattern_recognizer = PatternRecognizer()
        trends = pattern_recognizer.analyze_trends(health_data)
        
        # Apply filters
        if metric:
            trends = [t for t in trends if t['metric'] == metric]
        
        return trends
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error analyzing trends for user {current_user.id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Error analyzing trends")


@router.get("/health-alerts")
async def get_health_alerts(
    days_back: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    min_severity: float = Query(0.0, ge=0.0, le=1.0, description="Minimum severity threshold"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get health alerts that may require attention
    
    Args:
        days_back: Number of days of historical data to analyze
        min_severity: Minimum severity threshold for alerts
        current_user: Current authenticated user
        db: Database session
        
    Returns:
        List of health alerts
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_insights_engine import health_insights_engine
        from backend.ai.anomaly_detector import AnomalyDetector
        
        health_data = health_insights_engine._get_user_health_data(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        if health_data.empty:
            raise HTTPException(
                status_code=404,
                detail="No health data found for alert detection"
            )
        
        # Detect health alerts
        anomaly_detector = AnomalyDetector()
        alerts = anomaly_detector.detect_health_alerts(health_data)
        
        # Apply severity filter
        if min_severity > 0:
            alerts = [a for a in alerts if a['severity'] >= min_severity]
        
        return alerts
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error detecting health alerts for user {current_user.id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Error detecting health alerts")


@router.get("/goals/recommendations")
async def get_goal_recommendations(
    max_goals: int = Query(5, ge=1, le=10),
    difficulty: Optional[str] = Query(None, regex="^(easy|moderate|challenging|ambitious)$"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get AI-powered goal recommendations based on user health patterns.
    
    Returns personalized goal suggestions with difficulty levels, timelines,
    and success probabilities.
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.goal_optimizer import GoalOptimizer, GoalDifficulty
        
        # Convert difficulty string to enum
        difficulty_preference = None
        if difficulty:
            difficulty_preference = GoalDifficulty(difficulty)
        
        goal_optimizer = GoalOptimizer()
        recommendations = await goal_optimizer.generate_goal_recommendations(
            user_id=current_user.id,
            db=db,
            max_goals=max_goals,
            difficulty_preference=difficulty_preference
        )
        
        return {
            "recommendations": recommendations,
            "total_count": len(recommendations),
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error getting goal recommendations: {e}")
        raise HTTPException(status_code=500, detail="Failed to generate goal recommendations")

@router.post("/goals/{goal_id}/adjust")
async def adjust_goal(
    goal_id: str,
    progress_data: Dict[str, Any],
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get AI-powered goal adjustment recommendations based on current progress.
    
    Expected progress_data format:
    {
        "current_value": float,
        "target_value": float,
        "initial_value": float,
        "days_elapsed": int,
        "total_timeline": int
    }
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.goal_optimizer import GoalOptimizer
        
        goal_optimizer = GoalOptimizer()
        adjustment = await goal_optimizer.adjust_goal(
            goal_id=goal_id,
            user_id=current_user.id,
            db=db,
            progress_data=progress_data
        )
        
        if not adjustment:
            return {
                "adjustment_needed": False,
                "message": "Goal is on track, no adjustment needed at this time"
            }
        
        return {
            "adjustment_needed": True,
            "goal_id": goal_id,
            "adjustment_type": adjustment.adjustment_type,
            "new_target": adjustment.new_target,
            "reasoning": adjustment.reasoning,
            "confidence": adjustment.confidence,
            "expected_impact": adjustment.expected_impact,
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error adjusting goal: {e}")
        raise HTTPException(status_code=500, detail="Failed to adjust goal")

@router.post("/goals/coordinate")
async def coordinate_goals(
    goal_ids: List[str],
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get goal coordination recommendations for multiple goals.
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.goal_optimizer import GoalOptimizer
        
        goal_optimizer = GoalOptimizer()
        coordinations = await goal_optimizer.coordinate_multiple_goals(
            goal_ids=goal_ids,
            user_id=current_user.id,
            db=db
        )
        
        return {
            "coordinations": coordinations,
            "total_count": len(coordinations),
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error coordinating goals: {e}")
        raise HTTPException(status_code=500, detail="Failed to coordinate goals")

@router.get("/achievements")
async def get_achievements(
    date_range_days: int = Query(7, ge=1, le=90),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get detected achievements based on recent user activity.
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.achievement_engine import AchievementEngine
        
        achievement_engine = AchievementEngine()
        achievements = await achievement_engine.detect_achievements(
            user_id=current_user.id,
            db=db,
            date_range_days=date_range_days
        )
        
        return {
            "achievements": achievements,
            "total_count": len(achievements),
            "date_range_days": date_range_days,
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error getting achievements: {e}")
        raise HTTPException(status_code=500, detail="Failed to get achievements")

@router.get("/achievements/streaks")
async def get_user_streaks(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get current user streaks across different health metrics.
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.achievement_engine import AchievementEngine
        
        achievement_engine = AchievementEngine()
        streaks = await achievement_engine.get_user_streaks(
            user_id=current_user.id,
            db=db
        )
        
        return {
            "streaks": streaks,
            "total_count": len(streaks),
            "active_streaks": sum(1 for streak in streaks if streak > 0),
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error getting user streaks: {e}")
        raise HTTPException(status_code=500, detail="Failed to get user streaks")

@router.post("/achievements/{achievement_id}/celebrate")
async def create_celebration(
    achievement_id: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a celebration event for an achievement.
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.achievement_engine import AchievementEngine, Achievement, AchievementType, BadgeLevel, CelebrationLevel
        
        # First, get the achievement (this would typically come from a database)
        # For now, we'll create a mock achievement for the celebration
        mock_achievement = Achievement(
            id=achievement_id,
            achievement_type=AchievementType.MILESTONE,
            title="Sample Achievement",
            description="Sample achievement description",
            badge_level=BadgeLevel.GOLD,
            celebration_level=CelebrationLevel.MAJOR,
            earned_date=datetime.now(),
            metric_type="steps",
            achievement_value=10000,
            previous_best=None,
            improvement_percentage=None,
            streak_days=None,
            requirements_met=["Reached milestone"],
            next_milestone="Next: 12,000 steps",
            sharing_message="Achieved 10,000 steps!",
            motivation_message="Keep up the great work!"
        )
        
        achievement_engine = AchievementEngine()
        celebration = await achievement_engine.create_celebration_event(mock_achievement)
        
        if not celebration:
            raise HTTPException(status_code=404, detail="Achievement not found or celebration failed")
        
        return {
            "celebration": {
                "id": celebration.id,
                "achievement_id": celebration.achievement_id,
                "celebration_type": celebration.celebration_type,
                "celebration_level": celebration.celebration_level,
                "trigger_date": celebration.trigger_date.isoformat(),
                "message": celebration.message,
                "visual_elements": celebration.visual_elements,
                "sound_effects": celebration.sound_effects,
                "sharing_options": celebration.sharing_options,
                "follow_up_actions": celebration.follow_up_actions
            },
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error creating celebration: {e}")
        raise HTTPException(status_code=500, detail="Failed to create celebration")

@router.get("/coaching/messages")
async def get_coaching_messages(
    message_count: int = Query(3, ge=1, le=10),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get personalized coaching messages based on user health patterns and progress.
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_coach import HealthCoach
        
        health_coach = HealthCoach()
        messages = await health_coach.generate_coaching_messages(
            user_id=current_user.id,
            db=db,
            message_count=message_count
        )
        
        return {
            "messages": messages,
            "total_count": len(messages),
            "message_count": message_count,
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error getting coaching messages: {e}")
        raise HTTPException(status_code=500, detail="Failed to get coaching messages")

@router.post("/coaching/interventions")
async def create_behavioral_intervention(
    target_behavior: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Create a personalized behavioral intervention plan for a specific behavior.
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_coach import HealthCoach
        
        health_coach = HealthCoach()
        intervention = await health_coach.create_behavioral_intervention(
            user_id=current_user.id,
            db=db,
            target_behavior=target_behavior
        )
        
        if not intervention:
            raise HTTPException(status_code=400, detail="Unable to create intervention for specified behavior")
        
        return {
            "intervention": {
                "id": intervention.id,
                "intervention_type": intervention.intervention_type,
                "target_behavior": intervention.target_behavior,
                "current_pattern": intervention.current_pattern,
                "desired_pattern": intervention.desired_pattern,
                "intervention_strategy": intervention.intervention_strategy,
                "implementation_steps": intervention.implementation_steps,
                "success_metrics": intervention.success_metrics,
                "timeline_days": intervention.timeline_days,
                "difficulty_level": intervention.difficulty_level
            },
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error creating behavioral intervention: {e}")
        raise HTTPException(status_code=500, detail="Failed to create behavioral intervention")

@router.get("/coaching/progress")
async def get_coaching_progress(
    days: int = Query(30, ge=7, le=90),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get coaching progress summary including recent improvements and areas for focus.
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_coach import HealthCoach
        from backend.ai.achievement_engine import AchievementEngine
        
        # Get user health data for analysis
        end_date = datetime.now()
        start_date = end_date - timedelta(days=days)
        
        health_data = db.query(HealthMetricUnified).filter(
            HealthMetricUnified.user_id == current_user.id,
            HealthMetricUnified.timestamp >= start_date,
            HealthMetricUnified.timestamp <= end_date
        ).all()
        
        if not health_data:
            return {
                "progress_summary": "Insufficient data for progress analysis",
                "recommendations": ["Start tracking health metrics consistently"],
                "focus_areas": [],
                "achievements_count": 0,
                "days_analyzed": days
            }
        
        # Convert to DataFrame for analysis
        import pandas as pd
        data_list = []
        for record in health_data:
            data_list.append({
                'date': record.timestamp.date(),
                'metric_type': record.metric_type,
                'value': record.value,
                'unit': record.unit,
                'source': record.data_source
            })
        
        user_data = pd.DataFrame(data_list)
        
        # Analyze progress patterns
        health_coach = HealthCoach()
        progress_analysis = health_coach._analyze_recent_progress(user_data)
        
        # Get recent achievements
        achievement_engine = AchievementEngine()
        achievements = await achievement_engine.detect_achievements(
            user_id=current_user.id,
            db=db,
            date_range_days=days
        )
        
        # Generate focus areas
        focus_areas = []
        if progress_analysis.get("has_struggles"):
            for metric, decline in progress_analysis["struggles"].items():
                focus_areas.append({
                    "metric": metric,
                    "issue": f"Declined by {decline}%",
                    "recommendation": f"Focus on improving {metric} consistency"
                })
        
        return {
            "progress_summary": progress_analysis.get("summary", "No progress data available"),
            "improvements": progress_analysis.get("improvements", {}),
            "struggles": progress_analysis.get("struggles", {}),
            "focus_areas": focus_areas,
            "achievements_count": len(achievements),
            "days_analyzed": days,
            "generated_at": datetime.now().isoformat()
        }
        
    except Exception as e:
        logger.error(f"Error getting coaching progress: {e}")
        raise HTTPException(status_code=500, detail="Failed to get coaching progress") 

@router.get("/health-score-lazy", response_model=HealthScoreResponse)
async def get_health_score_lazy(
    days_back: int = Query(30, ge=7, le=365, description="Number of days to analyze"),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Get comprehensive health score using lazy imports to avoid numpy contamination
    """
    try:
        # Lazy import to avoid global numpy contamination
        from backend.ai.health_insights_engine import health_insights_engine
        
        health_score = health_insights_engine.calculate_health_score(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        if not health_score:
            raise HTTPException(
                status_code=404,
                detail="Insufficient health data to calculate score"
            )
        
        return HealthScoreResponse(
            overall_score=health_score.overall_score,
            activity_score=health_score.activity_score,
            sleep_score=health_score.sleep_score,
            nutrition_score=health_score.nutrition_score,
            heart_health_score=health_score.heart_health_score,
            consistency_score=health_score.consistency_score,
            trend_score=health_score.trend_score,
            last_updated=health_score.last_updated
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error calculating health score for user {current_user.id}: {str(e)}")
        raise HTTPException(status_code=500, detail="Error calculating health score") 
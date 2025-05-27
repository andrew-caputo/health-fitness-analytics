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

from core.database import get_db
from backend.api.deps import get_current_user
from core.models import User
from ai.health_insights_engine import health_insights_engine, HealthInsight, HealthScore
from pydantic import BaseModel

logger = logging.getLogger(__name__)

router = APIRouter()


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
        insights = health_insights_engine.generate_comprehensive_insights(
            user_id=current_user.id,
            days_back=days_back,
            db=db
        )
        
        # Count by priority
        priority_counts = {
            'high': len([i for i in insights if i.priority.value == 'high']),
            'medium': len([i for i in insights if i.priority.value == 'medium']),
            'low': len([i for i in insights if i.priority.value == 'low']),
            'critical': len([i for i in insights if i.priority.value == 'critical'])
        }
        
        # Count by category
        category_counts = {}
        for insight in insights:
            insight_type = insight.insight_type.value
            category_counts[insight_type] = category_counts.get(insight_type, 0) + 1
        
        # Get latest insights (top 5)
        latest_insights = []
        for insight in insights[:5]:
            latest_insights.append(HealthInsightResponse(
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
        # Get user's health data
        from ai.health_insights_engine import health_insights_engine
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
        from ai.recommendation_engine import RecommendationEngine
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
        # Get user's health data
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
        from ai.anomaly_detector import AnomalyDetector
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
        # Get user's health data
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
        from ai.pattern_recognition import PatternRecognizer
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
        # Get user's health data
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
        from ai.pattern_recognition import PatternRecognizer
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
        # Get user's health data
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
        from ai.anomaly_detector import AnomalyDetector
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
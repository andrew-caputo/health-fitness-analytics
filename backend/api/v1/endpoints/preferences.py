from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.models import User
from backend.api.deps import get_current_user
from backend.core.schemas import (
    UserDataSourcePreferences,
    UserDataSourcePreferencesCreate,
    UserDataSourcePreferencesUpdate,
    UserPreferencesResponse,
    DataSourceCapabilities
)
from backend.core.services.user_preferences import UserPreferencesService

router = APIRouter()

@router.get("/", response_model=UserPreferencesResponse)
async def get_user_preferences(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get user's data source preferences with context"""
    service = UserPreferencesService(db)
    return service.get_user_preferences_with_context(current_user.id)

@router.post("/", response_model=UserDataSourcePreferences)
async def create_user_preferences(
    preferences_data: UserDataSourcePreferencesCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create user's data source preferences"""
    service = UserPreferencesService(db)
    try:
        return service.create_user_preferences(current_user.id, preferences_data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.put("/", response_model=UserDataSourcePreferences)
async def update_user_preferences(
    preferences_data: UserDataSourcePreferencesUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update user's data source preferences"""
    service = UserPreferencesService(db)
    try:
        return service.update_user_preferences(current_user.id, preferences_data)
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        )

@router.delete("/")
async def delete_user_preferences(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete user's data source preferences"""
    service = UserPreferencesService(db)
    success = service.delete_user_preferences(current_user.id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User preferences not found"
        )
    
    return {"message": "Preferences deleted successfully"}

@router.get("/available-sources", response_model=List[DataSourceCapabilities])
async def get_available_data_sources(
    db: Session = Depends(get_db)
):
    """Get all available data sources and their capabilities"""
    from backend.core.models import DataSourceCapabilities as DataSourceCapabilitiesModel
    
    sources = db.query(DataSourceCapabilitiesModel).filter(
        DataSourceCapabilitiesModel.is_active == True
    ).all()
    
    return sources

@router.get("/category/{category}/sources")
async def get_sources_for_category(
    category: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get available and connected sources for a specific category"""
    if category not in ['activity', 'sleep', 'nutrition', 'body_composition']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid category. Must be one of: activity, sleep, nutrition, body_composition"
        )
    
    service = UserPreferencesService(db)
    
    # Get user's preferred source for this category
    preferred_source = service.get_preferred_source_for_category(current_user.id, category)
    
    # Get fallback sources
    fallback_sources = service.get_fallback_sources_for_category(current_user.id, category)
    
    # Get all available sources for this category
    from backend.core.models import DataSourceCapabilities as DataSourceCapabilitiesModel
    
    capability_field = f'supports_{category}'
    available_sources = db.query(DataSourceCapabilitiesModel).filter(
        getattr(DataSourceCapabilitiesModel, capability_field) == True,
        DataSourceCapabilitiesModel.is_active == True
    ).all()
    
    return {
        "category": category,
        "preferred_source": preferred_source,
        "connected_sources": fallback_sources,
        "available_sources": [
            {
                "source_name": source.source_name,
                "display_name": source.display_name,
                "integration_type": source.integration_type,
                "is_connected": service.is_source_connected(current_user.id, source.source_name)
            }
            for source in available_sources
        ]
    }

@router.post("/category/{category}/set-preferred")
async def set_preferred_source_for_category(
    category: str,
    source_name: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Set the preferred data source for a specific category"""
    if category not in ['activity', 'sleep', 'nutrition', 'body_composition']:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid category. Must be one of: activity, sleep, nutrition, body_composition"
        )
    
    service = UserPreferencesService(db)
    
    # Validate that the source exists and supports the category
    from backend.core.models import DataSourceCapabilities as DataSourceCapabilitiesModel
    
    capability_field = f'supports_{category}'
    source = db.query(DataSourceCapabilitiesModel).filter(
        DataSourceCapabilitiesModel.source_name == source_name,
        getattr(DataSourceCapabilitiesModel, capability_field) == True,
        DataSourceCapabilitiesModel.is_active == True
    ).first()
    
    if not source:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Data source '{source_name}' not found or does not support {category}"
        )
    
    # Check if user has this source connected
    if not service.is_source_connected(current_user.id, source_name):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Data source '{source_name}' is not connected. Please connect it first."
        )
    
    # Update user preferences
    current_preferences = service.get_user_preferences(current_user.id)
    
    update_data = {}
    if current_preferences:
        update_data = {
            'activity_source': current_preferences.activity_source,
            'sleep_source': current_preferences.sleep_source,
            'nutrition_source': current_preferences.nutrition_source,
            'body_composition_source': current_preferences.body_composition_source
        }
    
    update_data[f'{category}_source'] = source_name
    
    try:
        preferences_update = UserDataSourcePreferencesUpdate(**update_data)
        updated_preferences = service.update_user_preferences(current_user.id, preferences_update)
        
        return {
            "message": f"Preferred {category} source set to {source_name}",
            "preferences": updated_preferences
        }
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        ) 
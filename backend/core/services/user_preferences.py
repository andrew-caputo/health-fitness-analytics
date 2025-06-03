from datetime import datetime, UTC
from typing import Optional, List, Dict, Any
from uuid import UUID

from sqlalchemy.orm import Session
from sqlalchemy import and_

from ..models import UserDataSourcePreferences, DataSourceCapabilities, DataSourceConnection
from ..schemas import (
    UserDataSourcePreferencesCreate,
    UserDataSourcePreferencesUpdate,
    UserDataSourcePreferences as UserDataSourcePreferencesSchema,
    DataSourceStatus,
    UserPreferencesResponse
)

class UserPreferencesService:
    """Service for managing user data source preferences"""
    
    def __init__(self, db: Session):
        self.db = db
    
    def get_user_preferences(self, user_id: UUID) -> Optional[UserDataSourcePreferencesSchema]:
        """Get user's data source preferences"""
        preferences = self.db.query(UserDataSourcePreferences).filter(
            UserDataSourcePreferences.user_id == user_id
        ).first()
        
        if preferences:
            return UserDataSourcePreferencesSchema.from_orm(preferences)
        return None
    
    def create_user_preferences(
        self, 
        user_id: UUID, 
        preferences_data: UserDataSourcePreferencesCreate
    ) -> UserDataSourcePreferencesSchema:
        """Create new user preferences"""
        # Check if preferences already exist
        existing = self.db.query(UserDataSourcePreferences).filter(
            UserDataSourcePreferences.user_id == user_id
        ).first()
        
        if existing:
            raise ValueError("User preferences already exist. Use update instead.")
        
        # Validate data sources exist and are active
        self._validate_data_sources(preferences_data)
        
        preferences = UserDataSourcePreferences(
            user_id=user_id,
            activity_source=preferences_data.activity_source,
            sleep_source=preferences_data.sleep_source,
            nutrition_source=preferences_data.nutrition_source,
            body_composition_source=preferences_data.body_composition_source,
            heart_health_source=preferences_data.heart_health_source,
            priority_rules=preferences_data.priority_rules,
            conflict_resolution=preferences_data.conflict_resolution,
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC)
        )
        
        self.db.add(preferences)
        self.db.commit()
        self.db.refresh(preferences)
        
        return UserDataSourcePreferencesSchema.from_orm(preferences)
    
    def update_user_preferences(
        self, 
        user_id: UUID, 
        preferences_data: UserDataSourcePreferencesUpdate
    ) -> UserDataSourcePreferencesSchema:
        """Update existing user preferences"""
        preferences = self.db.query(UserDataSourcePreferences).filter(
            UserDataSourcePreferences.user_id == user_id
        ).first()
        
        if not preferences:
            # Create new preferences if they don't exist
            create_data = UserDataSourcePreferencesCreate(**preferences_data.model_dump())
            return self.create_user_preferences(user_id, create_data)
        
        # Validate data sources
        self._validate_data_sources(preferences_data)
        
        # Update fields that are provided
        update_data = preferences_data.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(preferences, field, value)
        
        preferences.updated_at = datetime.now(UTC)
        
        self.db.commit()
        self.db.refresh(preferences)
        
        return UserDataSourcePreferencesSchema.from_orm(preferences)
    
    def delete_user_preferences(self, user_id: UUID) -> bool:
        """Delete user preferences"""
        preferences = self.db.query(UserDataSourcePreferences).filter(
            UserDataSourcePreferences.user_id == user_id
        ).first()
        
        if preferences:
            self.db.delete(preferences)
            self.db.commit()
            return True
        return False
    
    def get_user_preferences_with_context(self, user_id: UUID) -> UserPreferencesResponse:
        """Get user preferences with available sources and connection status"""
        # Get user preferences
        preferences = self.get_user_preferences(user_id)
        
        # Get available data sources
        available_sources = self.db.query(DataSourceCapabilities).filter(
            DataSourceCapabilities.is_active == True
        ).all()
        
        # Get user's connected sources
        connected_sources = self._get_connected_sources_status(user_id)
        
        return UserPreferencesResponse(
            preferences=preferences,
            available_sources=[source for source in available_sources],
            connected_sources=connected_sources
        )
    
    def _validate_data_sources(self, preferences_data) -> None:
        """Validate that specified data sources exist and support the required categories"""
        sources_to_validate = [
            (preferences_data.activity_source, 'supports_activity'),
            (preferences_data.sleep_source, 'supports_sleep'),
            (preferences_data.nutrition_source, 'supports_nutrition'),
            (preferences_data.body_composition_source, 'supports_body_composition'),
            (preferences_data.heart_health_source, 'supports_heart_health')
        ]
        
        for source_name, capability_field in sources_to_validate:
            if source_name:
                source = self.db.query(DataSourceCapabilities).filter(
                    and_(
                        DataSourceCapabilities.source_name == source_name,
                        DataSourceCapabilities.is_active == True
                    )
                ).first()
                
                if not source:
                    raise ValueError(f"Data source '{source_name}' not found or inactive")
                
                if not getattr(source, capability_field):
                    category = capability_field.replace('supports_', '')
                    raise ValueError(f"Data source '{source_name}' does not support {category}")
    
    def _get_connected_sources_status(self, user_id: UUID) -> List[DataSourceStatus]:
        """Get status of all connected data sources for a user"""
        connections = self.db.query(DataSourceConnection).filter(
            DataSourceConnection.user_id == user_id
        ).all()
        
        # Get capabilities for all sources
        capabilities = {
            cap.source_name: cap 
            for cap in self.db.query(DataSourceCapabilities).all()
        }
        
        status_list = []
        for connection in connections:
            cap = capabilities.get(connection.source_type)
            if cap:
                status = DataSourceStatus(
                    source_name=connection.source_type,
                    display_name=cap.display_name,
                    is_connected=(connection.status == "connected"),
                    last_sync=connection.last_sync_at,
                    status=connection.status,
                    supports_activity=cap.supports_activity,
                    supports_sleep=cap.supports_sleep,
                    supports_nutrition=cap.supports_nutrition,
                    supports_body_composition=cap.supports_body_composition,
                    supports_heart_health=cap.supports_heart_health
                )
                status_list.append(status)
        
        return status_list
    
    def get_preferred_source_for_category(self, user_id: UUID, category: str) -> Optional[str]:
        """Get the user's preferred data source for a specific category"""
        preferences = self.get_user_preferences(user_id)
        if not preferences:
            return None
        
        category_mapping = {
            'activity': preferences.activity_source,
            'sleep': preferences.sleep_source,
            'nutrition': preferences.nutrition_source,
            'body_composition': preferences.body_composition_source,
            'heart_health': preferences.heart_health_source
        }
        
        return category_mapping.get(category)
    
    def is_source_connected(self, user_id: UUID, source_name: str) -> bool:
        """Check if a specific data source is connected for a user"""
        # Apple Health (HealthKit) is inherently connected if user has granted HealthKit permissions
        # We don't require explicit OAuth connection for device-local data sources
        if source_name == "apple_health":
            return True
        
        connection = self.db.query(DataSourceConnection).filter(
            and_(
                DataSourceConnection.user_id == user_id,
                DataSourceConnection.source_type == source_name,
                DataSourceConnection.status == "connected"
            )
        ).first()
        
        return connection is not None
    
    def get_fallback_sources_for_category(
        self, 
        user_id: UUID, 
        category: str
    ) -> List[str]:
        """Get fallback data sources for a category based on user's connected sources"""
        # Get user's connected sources
        connected_sources = self._get_connected_sources_status(user_id)
        
        # Filter sources that support the requested category
        category_field = f'supports_{category}'
        fallback_sources = [
            source.source_name 
            for source in connected_sources 
            if source.is_connected and getattr(source, category_field, False)
        ]
        
        # Get user's preferred source for this category
        preferred_source = self.get_preferred_source_for_category(user_id, category)
        
        # Remove preferred source from fallbacks and put it first
        if preferred_source in fallback_sources:
            fallback_sources.remove(preferred_source)
            fallback_sources.insert(0, preferred_source)
        
        return fallback_sources 
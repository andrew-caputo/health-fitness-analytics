from typing import Optional, Dict, Any, List
from datetime import datetime, timedelta
import asyncio
import httpx
import secrets
import base64
from urllib.parse import urlencode

from fastapi import APIRouter, Depends, HTTPException, status, BackgroundTasks
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.models import User, DataSourceConnection, HealthMetricUnified
from backend.api.deps import get_current_user
from backend.core.schemas import (
    DataSourceConnection as DataSourceConnectionSchema,
    HealthMetricUnified as HealthMetricUnifiedSchema
)
from backend.core.config import settings

router = APIRouter()

# FatSecret API configuration
FATSECRET_CLIENT_ID = settings.FATSECRET_CLIENT_ID
FATSECRET_CLIENT_SECRET = settings.FATSECRET_CLIENT_SECRET
FATSECRET_REDIRECT_URI = settings.FATSECRET_REDIRECT_URI

# FatSecret API endpoints
FATSECRET_TOKEN_URL = "https://oauth.fatsecret.com/connect/token"
FATSECRET_API_BASE_URL = "https://platform.fatsecret.com/rest/server.api"

# FatSecret OAuth2 scopes
FATSECRET_SCOPES = "basic"  # Basic scope for food search and nutrition data

# FatSecret API rate limits (varies by plan, basic is generous)
FATSECRET_RATE_LIMIT_REQUESTS = 1000
FATSECRET_RATE_LIMIT_PERIOD = 3600  # 1 hour


@router.get("/auth/url")
async def get_auth_url(current_user: User = Depends(get_current_user)):
    """Generate FatSecret OAuth2 authorization URL (Client Credentials flow)"""
    # FatSecret uses client credentials flow, so we don't need user authorization
    # We'll handle the token exchange directly in the connect endpoint
    state = secrets.token_urlsafe(32)
    
    return {
        "auth_url": f"/data-sources/fatsecret/auth/callback?state={state}",
        "state": state,
        "message": "FatSecret uses client credentials flow - click connect to authenticate"
    }


@router.post("/auth/callback")
async def auth_callback(
    state: str,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """Handle FatSecret OAuth2 callback and exchange credentials for tokens"""
    try:
        # FatSecret uses client credentials flow - exchange client credentials for access token
        async with httpx.AsyncClient() as client:
            # Prepare basic auth header
            credentials = f"{FATSECRET_CLIENT_ID}:{FATSECRET_CLIENT_SECRET}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()
            
            headers = {
                "Authorization": f"Basic {encoded_credentials}",
                "Content-Type": "application/x-www-form-urlencoded"
            }
            
            token_data = {
                "grant_type": "client_credentials",
                "scope": FATSECRET_SCOPES
            }
            
            response = await client.post(FATSECRET_TOKEN_URL, headers=headers, data=token_data)
            response.raise_for_status()
            token_response = response.json()
        
        # Extract tokens
        access_token = token_response["access_token"]
        expires_in = token_response.get("expires_in", 86400)  # Default 24 hours
        expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
        
        # Check if connection already exists
        existing_connection = db.query(DataSourceConnection).filter(
            DataSourceConnection.user_id == current_user.id,
            DataSourceConnection.source_type == "fatsecret"
        ).first()
        
        if existing_connection:
            # Update existing connection
            existing_connection.access_token = access_token
            existing_connection.refresh_token = None  # Client credentials flow doesn't use refresh tokens
            existing_connection.token_expires_at = expires_at
            existing_connection.is_active = True
            existing_connection.last_sync_at = datetime.utcnow()
            existing_connection.external_user_id = FATSECRET_CLIENT_ID  # Use client ID as identifier
            existing_connection.connection_metadata = {
                "scopes": [FATSECRET_SCOPES],
                "connected_at": datetime.utcnow().isoformat(),
                "auth_type": "client_credentials"
            }
            connection = existing_connection
        else:
            # Create new connection
            connection = DataSourceConnection(
                user_id=current_user.id,
                source_type="fatsecret",
                access_token=access_token,
                refresh_token=None,  # Client credentials flow doesn't use refresh tokens
                token_expires_at=expires_at,
                is_active=True,
                last_sync_at=datetime.utcnow(),
                external_user_id=FATSECRET_CLIENT_ID,
                connection_metadata={
                    "scopes": [FATSECRET_SCOPES],
                    "connected_at": datetime.utcnow().isoformat(),
                    "auth_type": "client_credentials"
                }
            )
            db.add(connection)
        
        db.commit()
        db.refresh(connection)
        
        # Schedule background sync to get initial nutrition data
        background_tasks.add_task(sync_fatsecret_data, current_user.id, db)
        
        return {
            "message": "FatSecret connected successfully",
            "connection_id": connection.id,
            "scopes": [FATSECRET_SCOPES]
        }
        
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to authenticate with FatSecret: {e.response.text}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Authentication failed: {str(e)}"
        )


@router.post("/sync")
async def sync_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    background_tasks: BackgroundTasks = BackgroundTasks()
):
    """Manually trigger FatSecret data synchronization"""
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "fatsecret",
        DataSourceConnection.is_active == True
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="FatSecret connection not found"
        )
    
    # Schedule background sync
    background_tasks.add_task(sync_fatsecret_data, current_user.id, db)
    
    return {"message": "FatSecret data sync initiated"}


@router.get("/data")
async def get_fatsecret_data(
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    metric_types: Optional[str] = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Retrieve FatSecret data for the authenticated user"""
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "fatsecret",
        DataSourceConnection.is_active == True
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="FatSecret connection not found"
        )
    
    # Build query for health metrics
    query = db.query(HealthMetricUnified).filter(
        HealthMetricUnified.user_id == current_user.id,
        HealthMetricUnified.source_type == "fatsecret"
    )
    
    # Apply date filters
    if start_date:
        start_dt = datetime.fromisoformat(start_date.replace('Z', '+00:00'))
        query = query.filter(HealthMetricUnified.recorded_at >= start_dt)
    
    if end_date:
        end_dt = datetime.fromisoformat(end_date.replace('Z', '+00:00'))
        query = query.filter(HealthMetricUnified.recorded_at <= end_dt)
    
    # Apply metric type filters
    if metric_types:
        types = [t.strip() for t in metric_types.split(',')]
        query = query.filter(HealthMetricUnified.metric_type.in_(types))
    
    metrics = query.order_by(HealthMetricUnified.recorded_at.desc()).all()
    
    return {
        "connection": {
            "id": connection.id,
            "connected_at": connection.created_at,
            "last_sync": connection.last_sync_at,
            "scopes": connection.connection_metadata.get("scopes", [])
        },
        "metrics": [
            {
                "id": metric.id,
                "metric_type": metric.metric_type,
                "value": metric.value,
                "unit": metric.unit,
                "recorded_at": metric.recorded_at,
                "metadata": metric.metadata
            }
            for metric in metrics
        ]
    }


@router.delete("/disconnect")
async def disconnect_fatsecret(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Disconnect FatSecret integration"""
    connection = db.query(DataSourceConnection).filter(
        DataSourceConnection.user_id == current_user.id,
        DataSourceConnection.source_type == "fatsecret"
    ).first()
    
    if not connection:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="FatSecret connection not found"
        )
    
    # Deactivate connection (no token revocation needed for client credentials)
    connection.is_active = False
    connection.access_token = None
    connection.refresh_token = None
    
    db.commit()
    
    return {"message": "FatSecret disconnected successfully"}


async def refresh_access_token(connection: DataSourceConnection, db: Session) -> bool:
    """Refresh FatSecret access token using client credentials"""
    try:
        async with httpx.AsyncClient() as client:
            # Prepare basic auth header
            credentials = f"{FATSECRET_CLIENT_ID}:{FATSECRET_CLIENT_SECRET}"
            encoded_credentials = base64.b64encode(credentials.encode()).decode()
            
            headers = {
                "Authorization": f"Basic {encoded_credentials}",
                "Content-Type": "application/x-www-form-urlencoded"
            }
            
            token_data = {
                "grant_type": "client_credentials",
                "scope": FATSECRET_SCOPES
            }
            
            response = await client.post(FATSECRET_TOKEN_URL, headers=headers, data=token_data)
            response.raise_for_status()
            token_response = response.json()
        
        # Update connection with new token
        access_token = token_response["access_token"]
        expires_in = token_response.get("expires_in", 86400)
        expires_at = datetime.utcnow() + timedelta(seconds=expires_in)
        
        connection.access_token = access_token
        connection.token_expires_at = expires_at
        
        db.commit()
        return True
        
    except Exception as e:
        print(f"Failed to refresh FatSecret token: {e}")
        return False


async def sync_fatsecret_data(user_id: int, db: Session):
    """Background task to sync FatSecret nutrition data"""
    try:
        connection = db.query(DataSourceConnection).filter(
            DataSourceConnection.user_id == user_id,
            DataSourceConnection.source_type == "fatsecret",
            DataSourceConnection.is_active == True
        ).first()
        
        if not connection:
            return
        
        # Check if token needs refresh
        if connection.token_expires_at and connection.token_expires_at <= datetime.utcnow():
            if not await refresh_access_token(connection, db):
                return
        
        # Sync popular foods and nutrition data
        await sync_nutrition_data(connection, db)
        
        # Update last sync time
        connection.last_sync_at = datetime.utcnow()
        db.commit()
        
    except Exception as e:
        print(f"FatSecret sync failed for user {user_id}: {e}")


async def sync_nutrition_data(connection: DataSourceConnection, db: Session):
    """Sync FatSecret nutrition data"""
    try:
        headers = {"Authorization": f"Bearer {connection.access_token}"}
        
        # Search for popular foods to populate nutrition database
        popular_foods = [
            "apple", "banana", "chicken breast", "salmon", "rice", "broccoli",
            "eggs", "milk", "bread", "pasta", "yogurt", "cheese", "spinach",
            "tomato", "potato", "avocado", "almonds", "oats", "quinoa", "beans"
        ]
        
        async with httpx.AsyncClient() as client:
            for food_term in popular_foods:
                try:
                    # Search for foods
                    search_params = {
                        "method": "foods.search",
                        "search_expression": food_term,
                        "format": "json",
                        "max_results": "5"
                    }
                    
                    response = await client.post(
                        FATSECRET_API_BASE_URL,
                        headers=headers,
                        data=search_params
                    )
                    
                    if response.status_code == 429:
                        # Rate limited - wait and retry
                        await asyncio.sleep(60)
                        continue
                    
                    response.raise_for_status()
                    search_data = response.json()
                    
                    # Process search results
                    if "foods" in search_data and "food" in search_data["foods"]:
                        foods = search_data["foods"]["food"]
                        if not isinstance(foods, list):
                            foods = [foods]
                        
                        for food in foods[:2]:  # Limit to 2 foods per search term
                            await process_food_item(food, connection, db, client, headers)
                    
                    # Rate limiting - wait between requests
                    await asyncio.sleep(1)
                    
                except Exception as e:
                    print(f"Failed to search for food '{food_term}': {e}")
                    continue
                
    except Exception as e:
        print(f"Failed to sync FatSecret nutrition data: {e}")


async def process_food_item(food: Dict[str, Any], connection: DataSourceConnection, db: Session, client: httpx.AsyncClient, headers: Dict[str, str]):
    """Process individual FatSecret food item"""
    try:
        food_id = food.get("food_id")
        food_name = food.get("food_name", "")
        
        if not food_id:
            return
        
        # Check if food already exists
        existing = db.query(HealthMetricUnified).filter(
            HealthMetricUnified.user_id == connection.user_id,
            HealthMetricUnified.source_type == "fatsecret",
            HealthMetricUnified.external_id == str(food_id)
        ).first()
        
        if existing:
            return  # Skip if already processed
        
        # Get detailed food information
        detail_params = {
            "method": "food.get.v4",
            "food_id": food_id,
            "format": "json"
        }
        
        detail_response = await client.post(
            FATSECRET_API_BASE_URL,
            headers=headers,
            data=detail_params
        )
        
        if detail_response.status_code != 200:
            return
        
        detail_data = detail_response.json()
        
        if "food" not in detail_data:
            return
        
        food_detail = detail_data["food"]
        
        # Extract nutrition information
        servings = food_detail.get("servings", {})
        if "serving" not in servings:
            return
        
        serving_data = servings["serving"]
        if isinstance(serving_data, list):
            serving_data = serving_data[0]  # Use first serving
        
        # Extract nutritional values
        calories = float(serving_data.get("calories", 0))
        carbs = float(serving_data.get("carbohydrate", 0))
        protein = float(serving_data.get("protein", 0))
        fat = float(serving_data.get("fat", 0))
        fiber = float(serving_data.get("fiber", 0))
        sugar = float(serving_data.get("sugar", 0))
        sodium = float(serving_data.get("sodium", 0))
        
        # Create nutrition summary metric
        nutrition_metric = HealthMetricUnified(
            user_id=connection.user_id,
            source_type="fatsecret",
            metric_type="nutrition_food",
            value=calories,
            unit="kcal",
            recorded_at=datetime.utcnow(),
            external_id=str(food_id),
            metadata={
                "food_name": food_name,
                "food_id": food_id,
                "calories": calories,
                "carbohydrates": carbs,
                "protein": protein,
                "fat": fat,
                "fiber": fiber,
                "sugar": sugar,
                "sodium": sodium,
                "serving_description": serving_data.get("serving_description", ""),
                "metric_serving_amount": serving_data.get("metric_serving_amount", ""),
                "metric_serving_unit": serving_data.get("metric_serving_unit", ""),
                "food_url": food_detail.get("food_url", "")
            }
        )
        db.add(nutrition_metric)
        
        # Create individual nutrient metrics
        nutrients = [
            ("calories", calories, "kcal"),
            ("carbohydrates", carbs, "g"),
            ("protein", protein, "g"),
            ("fat", fat, "g"),
            ("fiber", fiber, "g"),
            ("sugar", sugar, "g"),
            ("sodium", sodium, "mg")
        ]
        
        for nutrient_name, value, unit in nutrients:
            if value > 0:
                nutrient_metric = HealthMetricUnified(
                    user_id=connection.user_id,
                    source_type="fatsecret",
                    metric_type=f"nutrition_{nutrient_name}",
                    value=value,
                    unit=unit,
                    recorded_at=datetime.utcnow(),
                    external_id=f"{food_id}_{nutrient_name}",
                    metadata={
                        "food_name": food_name,
                        "food_id": food_id,
                        "nutrient_type": nutrient_name,
                        "serving_description": serving_data.get("serving_description", "")
                    }
                )
                db.add(nutrient_metric)
        
        db.commit()
        
    except Exception as e:
        print(f"Failed to process FatSecret food {food.get('food_id')}: {e}")
        db.rollback() 
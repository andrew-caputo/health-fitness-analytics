from typing import List, Optional
from uuid import UUID
import xml.etree.ElementTree as ET
from datetime import datetime
import zipfile
import os
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, BackgroundTasks
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.models import User, FileProcessingJob, HealthMetricUnified
from backend.api.deps import get_current_user
from backend.core.schemas import (
    FileProcessingJob as FileProcessingJobSchema,
    FileUploadResponse,
    HealthMetricUnified as HealthMetricUnifiedSchema
)

router = APIRouter()

# Apple Health data type mappings
APPLE_HEALTH_MAPPINGS = {
    # Activity metrics
    "HKQuantityTypeIdentifierStepCount": {"category": "activity", "metric_type": "steps", "unit": "count"},
    "HKQuantityTypeIdentifierDistanceWalkingRunning": {"category": "activity", "metric_type": "distance", "unit": "meters"},
    "HKQuantityTypeIdentifierActiveEnergyBurned": {"category": "activity", "metric_type": "active_energy", "unit": "kcal"},
    "HKQuantityTypeIdentifierBasalEnergyBurned": {"category": "activity", "metric_type": "basal_energy", "unit": "kcal"},
    "HKQuantityTypeIdentifierHeartRate": {"category": "activity", "metric_type": "heart_rate", "unit": "bpm"},
    
    # Sleep metrics
    "HKCategoryTypeIdentifierSleepAnalysis": {"category": "sleep", "metric_type": "sleep_analysis", "unit": "minutes"},
    
    # Nutrition metrics
    "HKQuantityTypeIdentifierDietaryEnergyConsumed": {"category": "nutrition", "metric_type": "dietary_energy", "unit": "kcal"},
    "HKQuantityTypeIdentifierDietaryWater": {"category": "nutrition", "metric_type": "water_intake", "unit": "ml"},
    "HKQuantityTypeIdentifierDietaryProtein": {"category": "nutrition", "metric_type": "protein", "unit": "g"},
    "HKQuantityTypeIdentifierDietaryCarbohydrates": {"category": "nutrition", "metric_type": "carbohydrates", "unit": "g"},
    "HKQuantityTypeIdentifierDietaryFatTotal": {"category": "nutrition", "metric_type": "fat", "unit": "g"},
    
    # Body composition metrics
    "HKQuantityTypeIdentifierBodyMass": {"category": "body_composition", "metric_type": "weight", "unit": "kg"},
    "HKQuantityTypeIdentifierBodyFatPercentage": {"category": "body_composition", "metric_type": "body_fat_percentage", "unit": "percent"},
    "HKQuantityTypeIdentifierBodyMassIndex": {"category": "body_composition", "metric_type": "bmi", "unit": "count"},
    "HKQuantityTypeIdentifierHeight": {"category": "body_composition", "metric_type": "height", "unit": "cm"},
}

@router.post("/upload", response_model=FileUploadResponse)
async def upload_apple_health_export(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Upload Apple Health export file for processing"""
    
    # Validate file type
    if not file.filename.endswith('.zip'):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be a ZIP archive from Apple Health export"
        )
    
    # Create upload directory if it doesn't exist
    upload_dir = Path("uploads/apple_health")
    upload_dir.mkdir(parents=True, exist_ok=True)
    
    # Save uploaded file
    file_path = upload_dir / f"{current_user.id}_{datetime.utcnow().timestamp()}_{file.filename}"
    
    try:
        with open(file_path, "wb") as buffer:
            content = await file.read()
            buffer.write(content)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to save uploaded file: {str(e)}"
        )
    
    # Create file processing job
    processing_job = FileProcessingJob(
        user_id=current_user.id,
        file_type="apple_health",
        filename=file.filename,
        file_path=str(file_path),
        status="pending",
        progress_percentage=0,
        processed_records=0,
        created_at=datetime.utcnow()
    )
    
    db.add(processing_job)
    db.commit()
    db.refresh(processing_job)
    
    # Start background processing
    background_tasks.add_task(process_apple_health_file, processing_job.id, str(file_path), db)
    
    return FileUploadResponse(
        job_id=processing_job.id,
        filename=file.filename,
        status="pending",
        message="Apple Health export uploaded successfully. Processing started in background."
    )

@router.get("/jobs/{job_id}", response_model=FileProcessingJobSchema)
async def get_processing_job_status(
    job_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get the status of an Apple Health processing job"""
    
    job = db.query(FileProcessingJob).filter(
        FileProcessingJob.id == job_id,
        FileProcessingJob.user_id == current_user.id,
        FileProcessingJob.file_type == "apple_health"
    ).first()
    
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Processing job not found"
        )
    
    return job

@router.get("/jobs", response_model=List[FileProcessingJobSchema])
async def get_user_processing_jobs(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all Apple Health processing jobs for the current user"""
    
    jobs = db.query(FileProcessingJob).filter(
        FileProcessingJob.user_id == current_user.id,
        FileProcessingJob.file_type == "apple_health"
    ).order_by(FileProcessingJob.created_at.desc()).all()
    
    return jobs

@router.get("/data", response_model=List[HealthMetricUnifiedSchema])
async def get_apple_health_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    category: Optional[str] = None,
    metric_type: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    limit: int = 100
):
    """Get processed Apple Health data for the current user"""
    
    query = db.query(HealthMetricUnified).filter(
        HealthMetricUnified.user_id == current_user.id,
        HealthMetricUnified.data_source == "apple_health"
    )
    
    if category:
        query = query.filter(HealthMetricUnified.category == category)
    
    if metric_type:
        query = query.filter(HealthMetricUnified.metric_type == metric_type)
    
    if start_date:
        query = query.filter(HealthMetricUnified.timestamp >= start_date)
    
    if end_date:
        query = query.filter(HealthMetricUnified.timestamp <= end_date)
    
    data = query.order_by(HealthMetricUnified.timestamp.desc()).limit(limit).all()
    
    return data

async def process_apple_health_file(job_id: UUID, file_path: str, db: Session):
    """Background task to process Apple Health export file"""
    
    # Get the processing job
    job = db.query(FileProcessingJob).filter(FileProcessingJob.id == job_id).first()
    if not job:
        return
    
    try:
        # Update job status
        job.status = "processing"
        job.started_at = datetime.utcnow()
        job.progress_percentage = 10
        db.commit()
        
        # Extract ZIP file
        extract_dir = Path(file_path).parent / f"extracted_{job_id}"
        extract_dir.mkdir(exist_ok=True)
        
        with zipfile.ZipFile(file_path, 'r') as zip_ref:
            zip_ref.extractall(extract_dir)
        
        job.progress_percentage = 20
        db.commit()
        
        # Find export.xml file
        export_xml_path = extract_dir / "apple_health_export" / "export.xml"
        if not export_xml_path.exists():
            raise Exception("export.xml not found in Apple Health export")
        
        job.progress_percentage = 30
        db.commit()
        
        # Parse XML and extract health data
        records_processed = parse_apple_health_xml(export_xml_path, job.user_id, db)
        
        job.progress_percentage = 90
        job.processed_records = records_processed
        db.commit()
        
        # Clean up extracted files
        import shutil
        shutil.rmtree(extract_dir)
        
        # Update job completion
        job.status = "completed"
        job.completed_at = datetime.utcnow()
        job.progress_percentage = 100
        db.commit()
        
    except Exception as e:
        # Update job with error
        job.status = "failed"
        job.error_message = str(e)
        job.completed_at = datetime.utcnow()
        db.commit()

def parse_apple_health_xml(xml_path: Path, user_id: UUID, db: Session) -> int:
    """Parse Apple Health export XML and extract health metrics"""
    
    records_processed = 0
    batch_size = 1000
    batch_records = []
    
    try:
        # Parse XML iteratively to handle large files
        context = ET.iterparse(xml_path, events=('start', 'end'))
        context = iter(context)
        event, root = next(context)
        
        for event, elem in context:
            if event == 'end' and elem.tag == 'Record':
                # Process health record
                record_type = elem.get('type')
                
                if record_type in APPLE_HEALTH_MAPPINGS:
                    mapping = APPLE_HEALTH_MAPPINGS[record_type]
                    
                    # Extract record data
                    value_str = elem.get('value')
                    start_date_str = elem.get('startDate')
                    
                    if value_str and start_date_str:
                        try:
                            # Parse value and timestamp
                            value = float(value_str)
                            timestamp = datetime.fromisoformat(start_date_str.replace('Z', '+00:00'))
                            
                            # Create unified health metric
                            metric = HealthMetricUnified(
                                user_id=user_id,
                                metric_type=mapping["metric_type"],
                                category=mapping["category"],
                                value=value,
                                unit=mapping["unit"],
                                timestamp=timestamp,
                                data_source="apple_health",
                                quality_score=0.9,  # High quality for Apple Health data
                                is_primary=True,
                                source_specific_data={
                                    "source_name": elem.get('sourceName'),
                                    "source_version": elem.get('sourceVersion'),
                                    "device": elem.get('device'),
                                    "creation_date": elem.get('creationDate'),
                                    "original_type": record_type
                                },
                                created_at=datetime.utcnow()
                            )
                            
                            batch_records.append(metric)
                            records_processed += 1
                            
                            # Batch insert for performance
                            if len(batch_records) >= batch_size:
                                db.add_all(batch_records)
                                db.commit()
                                batch_records = []
                                
                        except (ValueError, TypeError) as e:
                            # Skip invalid records
                            continue
                
                # Clear element to save memory
                elem.clear()
                root.clear()
        
        # Insert remaining records
        if batch_records:
            db.add_all(batch_records)
            db.commit()
            
    except ET.ParseError as e:
        raise Exception(f"Failed to parse Apple Health XML: {str(e)}")
    
    return records_processed 
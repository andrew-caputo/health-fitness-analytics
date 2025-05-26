from typing import List, Optional, Dict, Any
from uuid import UUID
import csv
import io
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, BackgroundTasks
from sqlalchemy.orm import Session

from backend.core.database import get_db
from backend.core.models import User, FileProcessingJob, HealthMetricUnified
from backend.api.deps import get_current_user
from backend.core.schemas import (
    FileProcessingJob as FileProcessingJobSchema,
    FileUploadResponse,
    HealthMetricUnified as HealthMetricUnifiedSchema,
    CSVImportRequest
)

router = APIRouter()

# Standard CSV column mappings
STANDARD_COLUMNS = {
    "timestamp": ["timestamp", "date", "datetime", "time"],
    "value": ["value", "amount", "quantity", "measurement"],
    "metric_type": ["metric_type", "type", "metric", "measurement_type"],
    "category": ["category", "cat", "group"],
    "unit": ["unit", "units", "measurement_unit"]
}

# Default category mappings for common metrics
DEFAULT_CATEGORY_MAPPINGS = {
    "steps": "activity",
    "distance": "activity", 
    "calories": "activity",
    "heart_rate": "activity",
    "sleep_duration": "sleep",
    "sleep_quality": "sleep",
    "weight": "body_composition",
    "body_fat": "body_composition",
    "bmi": "body_composition",
    "protein": "nutrition",
    "carbs": "nutrition",
    "fat": "nutrition",
    "water": "nutrition"
}

@router.post("/upload", response_model=FileUploadResponse)
async def upload_csv_file(
    background_tasks: BackgroundTasks,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Upload CSV file for health data import"""
    
    # Validate file type
    if not file.filename.endswith('.csv'):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="File must be a CSV file"
        )
    
    # Create upload directory if it doesn't exist
    upload_dir = Path("uploads/csv")
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
        file_type="csv",
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
    
    return FileUploadResponse(
        job_id=processing_job.id,
        filename=file.filename,
        status="pending",
        message="CSV file uploaded successfully. Use /configure endpoint to set up column mappings before processing."
    )

@router.post("/configure/{job_id}")
async def configure_csv_import(
    job_id: UUID,
    config: CSVImportRequest,
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Configure CSV import with column mappings and start processing"""
    
    job = db.query(FileProcessingJob).filter(
        FileProcessingJob.id == job_id,
        FileProcessingJob.user_id == current_user.id,
        FileProcessingJob.file_type == "csv",
        FileProcessingJob.status == "pending"
    ).first()
    
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Processing job not found or already processed"
        )
    
    # Store configuration in job metadata
    job.processing_metadata = {
        "column_mapping": config.column_mapping,
        "date_format": config.date_format,
        "file_type": config.file_type
    }
    db.commit()
    
    # Start background processing
    background_tasks.add_task(process_csv_file, job_id, db)
    
    return {"message": "CSV processing started with provided configuration"}

@router.get("/preview/{job_id}")
async def preview_csv_file(
    job_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Preview CSV file structure and suggest column mappings"""
    
    job = db.query(FileProcessingJob).filter(
        FileProcessingJob.id == job_id,
        FileProcessingJob.user_id == current_user.id,
        FileProcessingJob.file_type == "csv"
    ).first()
    
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Processing job not found"
        )
    
    try:
        # Read first few rows of CSV
        with open(job.file_path, 'r', encoding='utf-8') as file:
            # Try to detect delimiter
            sample = file.read(1024)
            file.seek(0)
            
            sniffer = csv.Sniffer()
            delimiter = sniffer.sniff(sample).delimiter
            
            reader = csv.DictReader(file, delimiter=delimiter)
            
            # Get column headers
            headers = reader.fieldnames
            
            # Read first 5 rows as preview
            preview_rows = []
            for i, row in enumerate(reader):
                if i >= 5:
                    break
                preview_rows.append(row)
        
        # Suggest column mappings
        suggested_mappings = suggest_column_mappings(headers)
        
        return {
            "headers": headers,
            "preview_rows": preview_rows,
            "suggested_mappings": suggested_mappings,
            "delimiter": delimiter
        }
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to preview CSV file: {str(e)}"
        )

@router.get("/jobs/{job_id}", response_model=FileProcessingJobSchema)
async def get_csv_processing_job_status(
    job_id: UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get the status of a CSV processing job"""
    
    job = db.query(FileProcessingJob).filter(
        FileProcessingJob.id == job_id,
        FileProcessingJob.user_id == current_user.id,
        FileProcessingJob.file_type == "csv"
    ).first()
    
    if not job:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Processing job not found"
        )
    
    return job

@router.get("/jobs", response_model=List[FileProcessingJobSchema])
async def get_user_csv_jobs(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all CSV processing jobs for the current user"""
    
    jobs = db.query(FileProcessingJob).filter(
        FileProcessingJob.user_id == current_user.id,
        FileProcessingJob.file_type == "csv"
    ).order_by(FileProcessingJob.created_at.desc()).all()
    
    return jobs

@router.get("/data", response_model=List[HealthMetricUnifiedSchema])
async def get_csv_imported_data(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
    category: Optional[str] = None,
    metric_type: Optional[str] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    limit: int = 100
):
    """Get imported CSV health data for the current user"""
    
    query = db.query(HealthMetricUnified).filter(
        HealthMetricUnified.user_id == current_user.id,
        HealthMetricUnified.data_source == "csv"
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

def suggest_column_mappings(headers: List[str]) -> Dict[str, str]:
    """Suggest column mappings based on header names"""
    
    suggestions = {}
    headers_lower = [h.lower() for h in headers]
    
    # Find best matches for standard columns
    for standard_col, possible_names in STANDARD_COLUMNS.items():
        for possible_name in possible_names:
            for i, header in enumerate(headers_lower):
                if possible_name in header:
                    suggestions[standard_col] = headers[i]
                    break
            if standard_col in suggestions:
                break
    
    return suggestions

async def process_csv_file(job_id: UUID, db: Session):
    """Background task to process CSV file"""
    
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
        
        # Get configuration from metadata
        config = job.processing_metadata
        column_mapping = config.get("column_mapping", {})
        date_format = config.get("date_format", "%Y-%m-%d %H:%M:%S")
        
        # Process CSV file
        records_processed = parse_csv_file(job.file_path, job.user_id, column_mapping, date_format, db)
        
        job.progress_percentage = 90
        job.processed_records = records_processed
        db.commit()
        
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

def parse_csv_file(file_path: str, user_id: UUID, column_mapping: Dict[str, str], date_format: str, db: Session) -> int:
    """Parse CSV file and extract health metrics"""
    
    records_processed = 0
    batch_size = 1000
    batch_records = []
    
    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            # Detect delimiter
            sample = file.read(1024)
            file.seek(0)
            
            sniffer = csv.Sniffer()
            delimiter = sniffer.sniff(sample).delimiter
            
            reader = csv.DictReader(file, delimiter=delimiter)
            
            for row in reader:
                try:
                    # Extract required fields using column mapping
                    timestamp_str = row.get(column_mapping.get("timestamp"))
                    value_str = row.get(column_mapping.get("value"))
                    metric_type = row.get(column_mapping.get("metric_type"))
                    category = row.get(column_mapping.get("category"))
                    unit = row.get(column_mapping.get("unit", ""), "")
                    
                    if not all([timestamp_str, value_str, metric_type]):
                        continue  # Skip rows with missing required data
                    
                    # Parse timestamp
                    try:
                        timestamp = datetime.strptime(timestamp_str, date_format)
                    except ValueError:
                        # Try common date formats
                        for fmt in ["%Y-%m-%d", "%m/%d/%Y", "%d/%m/%Y", "%Y-%m-%d %H:%M:%S"]:
                            try:
                                timestamp = datetime.strptime(timestamp_str, fmt)
                                break
                            except ValueError:
                                continue
                        else:
                            continue  # Skip if can't parse date
                    
                    # Parse value
                    value = float(value_str)
                    
                    # Determine category if not provided
                    if not category:
                        category = DEFAULT_CATEGORY_MAPPINGS.get(metric_type.lower(), "activity")
                    
                    # Create unified health metric
                    metric = HealthMetricUnified(
                        user_id=user_id,
                        metric_type=metric_type.lower(),
                        category=category.lower(),
                        value=value,
                        unit=unit,
                        timestamp=timestamp,
                        data_source="csv",
                        quality_score=0.7,  # Medium quality for CSV data
                        is_primary=False,  # CSV data is typically secondary
                        source_specific_data={
                            "original_row": dict(row),
                            "column_mapping": column_mapping
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
        
        # Insert remaining records
        if batch_records:
            db.add_all(batch_records)
            db.commit()
            
    except Exception as e:
        raise Exception(f"Failed to parse CSV file: {str(e)}")
    
    return records_processed 
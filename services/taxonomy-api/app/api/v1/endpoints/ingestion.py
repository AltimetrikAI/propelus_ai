"""
API endpoints for data ingestion into Bronze layer
"""
import json
from typing import List, Optional, Dict, Any
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel, validator
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, text
import boto3
import os
from datetime import datetime

from app.core.database import get_db

router = APIRouter()

# AWS clients
lambda_client = boto3.client('lambda')
BRONZE_INGESTION_LAMBDA = os.environ.get('BRONZE_INGESTION_LAMBDA', 'bronze-ingestion')


# Request models
class TaxonomyIngestionRequest(BaseModel):
    customer_id: int
    data: List[Dict[str, Any]]
    source_name: Optional[str] = None
    overwrite: bool = False

    @validator('data')
    def validate_data(cls, v):
        if not v or len(v) == 0:
            raise ValueError('Data cannot be empty')
        return v

    @validator('customer_id')
    def validate_customer_id(cls, v):
        if v <= 0:
            raise ValueError('Customer ID must be positive')
        return v


class ProfessionIngestionRequest(BaseModel):
    customer_id: int
    data: List[Dict[str, Any]]
    source_name: Optional[str] = None
    overwrite: bool = False

    @validator('data')
    def validate_data(cls, v):
        if not v or len(v) == 0:
            raise ValueError('Data cannot be empty')
        return v


class BulkIngestionRequest(BaseModel):
    customer_id: int
    taxonomies: Optional[List[Dict[str, Any]]] = []
    professions: Optional[List[Dict[str, Any]]] = []
    source_name: Optional[str] = None
    overwrite: bool = False


# Response models
class IngestionResponse(BaseModel):
    source_id: int
    status: str
    records_processed: int
    message: str
    estimated_processing_time: str


class IngestionStatusResponse(BaseModel):
    source_id: int
    status: str
    record_count: Optional[int]
    created_at: str
    processed_at: Optional[str]
    error_message: Optional[str]
    processing_stages: List[Dict[str, Any]]


@router.post("/ingestion/bronze/taxonomies", response_model=IngestionResponse)
async def ingest_taxonomies(
    request: TaxonomyIngestionRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    """
    Ingest taxonomy data into Bronze layer

    This endpoint accepts hierarchical taxonomy data and processes it through
    the Bronze -> Silver -> Gold pipeline.
    """
    try:
        # Validate customer exists
        await validate_customer(db, request.customer_id)

        # Prepare payload for Bronze ingestion Lambda
        payload = {
            'customer_id': request.customer_id,
            'data': request.data,
            'type': 'taxonomy',
            'source_name': request.source_name or f"API_taxonomy_{datetime.now().isoformat()}",
            'overwrite': request.overwrite
        }

        # Invoke Bronze ingestion Lambda asynchronously
        response = lambda_client.invoke(
            FunctionName=BRONZE_INGESTION_LAMBDA,
            InvocationType='Event',  # Async invocation
            Payload=json.dumps(payload)
        )

        # Create source tracking record
        source_id = await create_ingestion_tracking(
            db,
            request.customer_id,
            'taxonomy',
            len(request.data),
            request.source_name
        )

        return IngestionResponse(
            source_id=source_id,
            status='processing',
            records_processed=len(request.data),
            message=f'Taxonomy ingestion started for customer {request.customer_id}',
            estimated_processing_time='2-5 minutes'
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ingestion failed: {str(e)}")


@router.post("/ingestion/bronze/professions", response_model=IngestionResponse)
async def ingest_professions(
    request: ProfessionIngestionRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    """
    Ingest profession data into Bronze layer

    This endpoint accepts flat profession data with attributes and maps them
    to existing taxonomies.
    """
    try:
        # Validate customer exists
        await validate_customer(db, request.customer_id)

        # Prepare payload for Bronze ingestion Lambda
        payload = {
            'customer_id': request.customer_id,
            'data': request.data,
            'type': 'profession',
            'source_name': request.source_name or f"API_profession_{datetime.now().isoformat()}",
            'overwrite': request.overwrite
        }

        # Invoke Bronze ingestion Lambda asynchronously
        response = lambda_client.invoke(
            FunctionName=BRONZE_INGESTION_LAMBDA,
            InvocationType='Event',
            Payload=json.dumps(payload)
        )

        # Create source tracking record
        source_id = await create_ingestion_tracking(
            db,
            request.customer_id,
            'profession',
            len(request.data),
            request.source_name
        )

        return IngestionResponse(
            source_id=source_id,
            status='processing',
            records_processed=len(request.data),
            message=f'Profession ingestion started for customer {request.customer_id}',
            estimated_processing_time='1-3 minutes'
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Ingestion failed: {str(e)}")


@router.post("/ingestion/bronze/bulk", response_model=IngestionResponse)
async def ingest_bulk_data(
    request: BulkIngestionRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db)
):
    """
    Ingest both taxonomy and profession data in a single request

    This endpoint handles complete data sets including both hierarchical
    taxonomies and flat profession lists.
    """
    try:
        # Validate customer exists
        await validate_customer(db, request.customer_id)

        total_records = len(request.taxonomies) + len(request.professions)

        if total_records == 0:
            raise HTTPException(status_code=400, detail="No data provided for ingestion")

        # Prepare payload for Bronze ingestion Lambda
        payload = {
            'customer_id': request.customer_id,
            'taxonomies': request.taxonomies,
            'professions': request.professions,
            'type': 'bulk',
            'source_name': request.source_name or f"API_bulk_{datetime.now().isoformat()}",
            'overwrite': request.overwrite
        }

        # Invoke Bronze ingestion Lambda asynchronously
        response = lambda_client.invoke(
            FunctionName=BRONZE_INGESTION_LAMBDA,
            InvocationType='Event',
            Payload=json.dumps(payload)
        )

        # Create source tracking record
        source_id = await create_ingestion_tracking(
            db,
            request.customer_id,
            'bulk',
            total_records,
            request.source_name
        )

        return IngestionResponse(
            source_id=source_id,
            status='processing',
            records_processed=total_records,
            message=f'Bulk ingestion started for customer {request.customer_id}',
            estimated_processing_time='3-10 minutes'
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Bulk ingestion failed: {str(e)}")


@router.get("/ingestion/status/{source_id}", response_model=IngestionStatusResponse)
async def get_ingestion_status(
    source_id: int,
    db: AsyncSession = Depends(get_db)
):
    """
    Get the status of a specific ingestion process

    Returns detailed information about the processing pipeline status
    including any errors or completion status.
    """
    try:
        # Get source information
        source_query = text("""
            SELECT source_id, customer_id, source_type, source_name,
                   record_count, import_status, error_message,
                   created_at, processed_at
            FROM bronze_data_sources
            WHERE source_id = :source_id
        """)

        result = await db.execute(source_query, {'source_id': source_id})
        source = result.fetchone()

        if not source:
            raise HTTPException(status_code=404, detail=f"Source ID {source_id} not found")

        # Get processing stages
        stages_query = text("""
            SELECT stage, status, records_processed, records_failed,
                   processing_time_ms, error_details, created_at
            FROM processing_log
            WHERE source_id = :source_id
            ORDER BY created_at ASC
        """)

        stages_result = await db.execute(stages_query, {'source_id': source_id})
        stages = stages_result.fetchall()

        processing_stages = []
        for stage in stages:
            processing_stages.append({
                'stage': stage.stage,
                'status': stage.status,
                'records_processed': stage.records_processed,
                'records_failed': stage.records_failed or 0,
                'processing_time_ms': stage.processing_time_ms,
                'error_details': stage.error_details,
                'timestamp': stage.created_at.isoformat() if stage.created_at else None
            })

        return IngestionStatusResponse(
            source_id=source.source_id,
            status=source.import_status,
            record_count=source.record_count,
            created_at=source.created_at.isoformat() if source.created_at else None,
            processed_at=source.processed_at.isoformat() if source.processed_at else None,
            error_message=source.error_message,
            processing_stages=processing_stages
        )

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error retrieving status: {str(e)}")


@router.get("/ingestion/sources")
async def list_ingestion_sources(
    customer_id: Optional[int] = None,
    status: Optional[str] = None,
    source_type: Optional[str] = None,
    limit: int = 50,
    offset: int = 0,
    db: AsyncSession = Depends(get_db)
):
    """
    List ingestion sources with optional filtering

    Useful for monitoring and tracking all ingestion activities.
    """
    try:
        conditions = []
        params = {'limit': limit, 'offset': offset}

        if customer_id:
            conditions.append("customer_id = :customer_id")
            params['customer_id'] = customer_id

        if status:
            conditions.append("import_status = :status")
            params['status'] = status

        if source_type:
            conditions.append("source_type = :source_type")
            params['source_type'] = source_type

        where_clause = "WHERE " + " AND ".join(conditions) if conditions else ""

        query = text(f"""
            SELECT source_id, customer_id, source_type, source_name,
                   record_count, import_status, created_at, processed_at,
                   error_message
            FROM bronze_data_sources
            {where_clause}
            ORDER BY created_at DESC
            LIMIT :limit OFFSET :offset
        """)

        result = await db.execute(query, params)
        sources = result.fetchall()

        # Get total count
        count_query = text(f"""
            SELECT COUNT(*) as total
            FROM bronze_data_sources
            {where_clause}
        """)

        count_result = await db.execute(count_query, {k: v for k, v in params.items()
                                                    if k not in ['limit', 'offset']})
        total = count_result.fetchone().total

        return {
            'sources': [
                {
                    'source_id': s.source_id,
                    'customer_id': s.customer_id,
                    'source_type': s.source_type,
                    'source_name': s.source_name,
                    'record_count': s.record_count,
                    'status': s.import_status,
                    'created_at': s.created_at.isoformat() if s.created_at else None,
                    'processed_at': s.processed_at.isoformat() if s.processed_at else None,
                    'error_message': s.error_message
                }
                for s in sources
            ],
            'total': total,
            'limit': limit,
            'offset': offset
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error listing sources: {str(e)}")


@router.post("/ingestion/{source_id}/reprocess")
async def reprocess_source(
    source_id: int,
    stage: Optional[str] = None,  # 'bronze', 'silver', 'mapping', 'all'
    db: AsyncSession = Depends(get_db)
):
    """
    Reprocess a source through the pipeline

    Useful for retrying failed processes or applying updated rules
    to existing data.
    """
    try:
        # Validate source exists
        source_query = text("""
            SELECT source_id, customer_id, import_status
            FROM bronze_data_sources
            WHERE source_id = :source_id
        """)

        result = await db.execute(source_query, {'source_id': source_id})
        source = result.fetchone()

        if not source:
            raise HTTPException(status_code=404, detail=f"Source ID {source_id} not found")

        # Determine which Lambda to invoke
        stage = stage or 'all'

        if stage in ['bronze', 'all']:
            # Reingest from Bronze
            lambda_client.invoke(
                FunctionName=BRONZE_INGESTION_LAMBDA,
                InvocationType='Event',
                Payload=json.dumps({'source_id': source_id, 'reprocess': True})
            )
        elif stage in ['silver', 'all']:
            # Reprocess Silver layer
            lambda_client.invoke(
                FunctionName='silver-processing',
                InvocationType='Event',
                Payload=json.dumps({'source_id': source_id, 'reprocess': True})
            )
        elif stage in ['mapping', 'all']:
            # Reprocess mapping rules
            lambda_client.invoke(
                FunctionName='mapping-rules',
                InvocationType='Event',
                Payload=json.dumps({'source_id': source_id, 'reprocess': True})
            )

        return {
            'source_id': source_id,
            'status': 'reprocess_started',
            'stage': stage,
            'message': f'Reprocessing initiated for stage: {stage}'
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Reprocessing failed: {str(e)}")


# Helper functions
async def validate_customer(db: AsyncSession, customer_id: int):
    """Validate that customer exists (placeholder - implement based on your customer model)"""
    # For now, just validate it's a positive number
    if customer_id <= 0:
        raise HTTPException(status_code=400, detail="Invalid customer ID")


async def create_ingestion_tracking(
    db: AsyncSession,
    customer_id: int,
    source_type: str,
    record_count: int,
    source_name: Optional[str] = None
) -> int:
    """Create a tracking record for ingestion"""

    query = text("""
        INSERT INTO bronze_data_sources
        (customer_id, source_type, source_name, record_count, import_status, created_at)
        VALUES (:customer_id, :source_type, :source_name, :record_count, 'processing', NOW())
        RETURNING source_id
    """)

    result = await db.execute(query, {
        'customer_id': customer_id,
        'source_type': source_type,
        'source_name': source_name,
        'record_count': record_count
    })

    await db.commit()
    return result.fetchone()[0]
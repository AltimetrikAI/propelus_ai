"""
Bronze Layer Ingestion Lambda Handler
Processes raw data from S3/API into Bronze layer tables
"""
import json
import csv
import io
import uuid
from datetime import datetime
from typing import Dict, Any, List, Optional
import boto3
import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.orm import Session
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DATABASE_URL = os.environ.get('DATABASE_URL')
S3_BUCKET = os.environ.get('S3_BUCKET')
SQS_QUEUE_URL = os.environ.get('SILVER_PROCESSING_QUEUE')

# AWS clients
s3_client = boto3.client('s3')
sqs_client = boto3.client('sqs')

# Database connection
engine = None
if DATABASE_URL:
    engine = create_engine(DATABASE_URL)


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for Bronze layer ingestion

    Event sources:
    - S3 PUT events
    - API Gateway POST requests
    - Manual invocation
    """
    try:
        # Determine event source
        if 'Records' in event and event['Records'][0].get('s3'):
            # S3 trigger
            return process_s3_event(event)
        elif 'httpMethod' in event:
            # API Gateway trigger
            return process_api_event(event)
        else:
            # Direct invocation
            return process_direct_invocation(event)

    except Exception as e:
        logger.error(f"Error processing event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def process_s3_event(event: Dict[str, Any]) -> Dict[str, Any]:
    """Process files uploaded to S3"""
    results = []

    for record in event.get('Records', []):
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']

        logger.info(f"Processing S3 file: {bucket}/{key}")

        # Create source tracking record
        source_id = create_data_source_record(
            source_type='file',
            source_name=key,
            file_path=f"s3://{bucket}/{key}",
            file_size_bytes=record['s3']['object'].get('size')
        )

        # Download and process file
        try:
            file_content = download_s3_file(bucket, key)
            file_type = determine_file_type(key)

            if file_type == 'csv':
                data = parse_csv(file_content)
            elif file_type == 'json':
                data = parse_json(file_content)
            elif file_type == 'excel':
                data = parse_excel(file_content)
            else:
                raise ValueError(f"Unsupported file type: {file_type}")

            # Determine data type (taxonomy or profession)
            data_type = determine_data_type(data)

            # Store in Bronze layer
            if data_type == 'taxonomy':
                store_bronze_taxonomies(data, source_id)
            else:
                store_bronze_professions(data, source_id)

            # Update source status
            update_source_status(source_id, 'completed', len(data))

            # Trigger Silver processing
            trigger_silver_processing(source_id)

            results.append({
                'file': key,
                'source_id': source_id,
                'records': len(data),
                'status': 'success'
            })

        except Exception as e:
            logger.error(f"Error processing file {key}: {str(e)}")
            update_source_status(source_id, 'failed', error_message=str(e))
            results.append({
                'file': key,
                'source_id': source_id,
                'status': 'failed',
                'error': str(e)
            })

    return {
        'statusCode': 200,
        'body': json.dumps({'results': results})
    }


def process_api_event(event: Dict[str, Any]) -> Dict[str, Any]:
    """Process data sent via API"""
    try:
        body = json.loads(event.get('body', '{}'))
        customer_id = body.get('customer_id')
        data = body.get('data', [])
        data_type = body.get('type', 'profession')  # 'taxonomy' or 'profession'

        if not customer_id or not data:
            return {
                'statusCode': 400,
                'body': json.dumps({'error': 'Missing required fields: customer_id, data'})
            }

        # Create source tracking record
        source_id = create_data_source_record(
            source_type='api',
            source_name=f"API_{data_type}_{datetime.now().isoformat()}",
            customer_id=customer_id,
            request_id=event.get('requestContext', {}).get('requestId')
        )

        # Store in Bronze layer
        if data_type == 'taxonomy':
            store_bronze_taxonomies(data, source_id, customer_id)
        else:
            store_bronze_professions(data, source_id, customer_id)

        # Update source status
        update_source_status(source_id, 'completed', len(data))

        # Trigger Silver processing
        trigger_silver_processing(source_id)

        return {
            'statusCode': 200,
            'body': json.dumps({
                'source_id': source_id,
                'records_processed': len(data),
                'status': 'success'
            })
        }

    except Exception as e:
        logger.error(f"Error processing API event: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def process_direct_invocation(event: Dict[str, Any]) -> Dict[str, Any]:
    """Process direct Lambda invocation"""
    # Similar to API processing but for internal calls
    return process_api_event({'body': json.dumps(event)})


def create_data_source_record(
    source_type: str,
    source_name: str,
    customer_id: Optional[int] = None,
    file_path: Optional[str] = None,
    file_size_bytes: Optional[int] = None,
    request_id: Optional[str] = None
) -> int:
    """Create a record in bronze_data_sources table"""
    with Session(engine) as session:
        query = """
        INSERT INTO bronze_data_sources
        (customer_id, source_type, source_name, file_path, file_size_bytes,
         request_id, import_status, created_at)
        VALUES (%s, %s, %s, %s, %s, %s, 'processing', NOW())
        RETURNING source_id
        """
        result = session.execute(query, (
            customer_id, source_type, source_name, file_path,
            file_size_bytes, request_id
        ))
        session.commit()
        return result.fetchone()[0]


def update_source_status(
    source_id: int,
    status: str,
    record_count: Optional[int] = None,
    error_message: Optional[str] = None
):
    """Update the status of a data source"""
    with Session(engine) as session:
        query = """
        UPDATE bronze_data_sources
        SET import_status = %s,
            record_count = %s,
            error_message = %s,
            processed_at = NOW()
        WHERE source_id = %s
        """
        session.execute(query, (status, record_count, error_message, source_id))
        session.commit()


def store_bronze_taxonomies(data: List[Dict], source_id: int, customer_id: Optional[int] = None):
    """Store taxonomy data in bronze_taxonomies table"""
    with Session(engine) as session:
        for row in data:
            # Extract customer_id from data if not provided
            if not customer_id:
                customer_id = row.get('customer_id')

            query = """
            INSERT INTO bronze_taxonomies
            (customer_id, row_json, load_date, type, source_id)
            VALUES (%s, %s, NOW(), %s, %s)
            """

            # Determine if new or updated (simplified logic)
            load_type = 'new' if not row.get('update_flag') else 'updated'

            session.execute(query, (
                customer_id,
                json.dumps(row),
                load_type,
                source_id
            ))
        session.commit()


def store_bronze_professions(data: List[Dict], source_id: int, customer_id: Optional[int] = None):
    """Store profession data in bronze_professions table"""
    with Session(engine) as session:
        for row in data:
            # Extract customer_id from data if not provided
            if not customer_id:
                customer_id = row.get('customer_id')

            query = """
            INSERT INTO bronze_professions
            (customer_id, row_json, load_date, type, source_id)
            VALUES (%s, %s, NOW(), %s, %s)
            """

            # Determine if new or updated
            load_type = 'new' if not row.get('update_flag') else 'updated'

            session.execute(query, (
                customer_id,
                json.dumps(row),
                load_type,
                source_id
            ))
        session.commit()


def trigger_silver_processing(source_id: int):
    """Send message to SQS to trigger Silver layer processing"""
    if not SQS_QUEUE_URL:
        logger.warning("SQS_QUEUE_URL not configured, skipping Silver trigger")
        return

    message = {
        'source_id': source_id,
        'timestamp': datetime.now().isoformat(),
        'action': 'process_silver'
    }

    try:
        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message)
        )
        logger.info(f"Triggered Silver processing for source_id {source_id}: {response['MessageId']}")
    except Exception as e:
        logger.error(f"Failed to trigger Silver processing: {str(e)}")


def download_s3_file(bucket: str, key: str) -> bytes:
    """Download file from S3"""
    response = s3_client.get_object(Bucket=bucket, Key=key)
    return response['Body'].read()


def determine_file_type(filename: str) -> str:
    """Determine file type from extension"""
    ext = filename.lower().split('.')[-1]
    if ext == 'csv':
        return 'csv'
    elif ext in ['json', 'jsonl']:
        return 'json'
    elif ext in ['xls', 'xlsx']:
        return 'excel'
    else:
        return 'unknown'


def parse_csv(content: bytes) -> List[Dict]:
    """Parse CSV content"""
    text = content.decode('utf-8')
    reader = csv.DictReader(io.StringIO(text))
    return list(reader)


def parse_json(content: bytes) -> List[Dict]:
    """Parse JSON content"""
    text = content.decode('utf-8')
    # Handle both single JSON object and JSONL format
    if text.startswith('['):
        return json.loads(text)
    else:
        # JSONL format
        return [json.loads(line) for line in text.strip().split('\n')]


def parse_excel(content: bytes) -> List[Dict]:
    """Parse Excel content"""
    df = pd.read_excel(io.BytesIO(content))
    return df.to_dict('records')


def determine_data_type(data: List[Dict]) -> str:
    """
    Determine if data is taxonomy or profession based on columns

    Taxonomy typically has: hierarchy levels, parent relationships
    Profession typically has: flat structure, state, profession code
    """
    if not data:
        return 'unknown'

    first_row = data[0]
    keys = set(first_row.keys())

    # Check for taxonomy indicators
    taxonomy_indicators = {'parent_id', 'level', 'node_type', 'hierarchy'}
    if keys & taxonomy_indicators:
        return 'taxonomy'

    # Check for profession indicators
    profession_indicators = {'state', 'profession_code', 'license_type'}
    if keys & profession_indicators:
        return 'profession'

    # Default to profession if unclear
    return 'profession'


# Add processing log
def create_processing_log(source_id: int, stage: str, status: str,
                         records_processed: int = 0, error_details: Dict = None):
    """Create entry in processing_log table"""
    with Session(engine) as session:
        query = """
        INSERT INTO processing_log
        (source_id, stage, status, records_processed, error_details, created_at)
        VALUES (%s, %s, %s, %s, %s, NOW())
        """
        session.execute(query, (
            source_id, stage, status, records_processed,
            json.dumps(error_details) if error_details else None
        ))
        session.commit()
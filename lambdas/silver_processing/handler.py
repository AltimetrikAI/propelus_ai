"""
Silver Layer Processing Lambda Handler
Processes Bronze layer data into structured Silver layer tables
"""
import json
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple
import os
import boto3
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DATABASE_URL = os.environ.get('DATABASE_URL')
SQS_QUEUE_URL = os.environ.get('MAPPING_RULES_QUEUE')

# AWS clients
sqs_client = boto3.client('sqs')

# Database connection
engine = None
if DATABASE_URL:
    engine = create_engine(DATABASE_URL)


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for Silver layer processing

    Triggered by:
    - SQS message from Bronze ingestion
    - Direct invocation for reprocessing
    """
    try:
        # Process SQS records if present
        if 'Records' in event:
            results = []
            for record in event['Records']:
                message = json.loads(record['body'])
                source_id = message.get('source_id')

                if not source_id:
                    logger.error("No source_id in message")
                    continue

                result = process_source(source_id)
                results.append(result)

            return {
                'statusCode': 200,
                'body': json.dumps({'results': results})
            }
        else:
            # Direct invocation
            source_id = event.get('source_id')
            if not source_id:
                return {
                    'statusCode': 400,
                    'body': json.dumps({'error': 'source_id required'})
                }

            result = process_source(source_id)
            return {
                'statusCode': 200,
                'body': json.dumps(result)
            }

    except Exception as e:
        logger.error(f"Error in Silver processing: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def process_source(source_id: int) -> Dict[str, Any]:
    """Process all Bronze data for a given source_id"""
    logger.info(f"Processing source_id: {source_id}")

    # Create processing log entry
    log_processing_start(source_id, 'silver_processing')

    try:
        # Get source information
        source_info = get_source_info(source_id)
        if not source_info:
            raise ValueError(f"Source {source_id} not found")

        customer_id = source_info['customer_id']

        # Process taxonomies
        taxonomy_count = process_bronze_taxonomies(source_id, customer_id)

        # Process professions
        profession_count = process_bronze_professions(source_id, customer_id)

        # Update processing log
        log_processing_complete(source_id, 'silver_processing',
                               taxonomy_count + profession_count)

        # Trigger mapping rules processing if data was processed
        if taxonomy_count > 0 or profession_count > 0:
            trigger_mapping_rules(source_id)

        return {
            'source_id': source_id,
            'taxonomies_processed': taxonomy_count,
            'professions_processed': profession_count,
            'status': 'success'
        }

    except Exception as e:
        logger.error(f"Error processing source {source_id}: {str(e)}")
        log_processing_error(source_id, 'silver_processing', str(e))
        return {
            'source_id': source_id,
            'status': 'failed',
            'error': str(e)
        }


def process_bronze_taxonomies(source_id: int, customer_id: int) -> int:
    """Process taxonomy data from Bronze to Silver"""
    with Session(engine) as session:
        # Get Bronze taxonomy data
        bronze_data = session.execute(
            text("""
            SELECT bronze_id, row_json, type
            FROM bronze_taxonomies
            WHERE source_id = :source_id
            """),
            {'source_id': source_id}
        ).fetchall()

        if not bronze_data:
            return 0

        # Process each Bronze record
        for bronze_id, row_json, load_type in bronze_data:
            data = json.loads(row_json) if isinstance(row_json, str) else row_json

            # Create or update taxonomy in Silver
            taxonomy_id = create_or_update_taxonomy(session, customer_id, data, source_id)

            # Process nodes if present
            if 'nodes' in data:
                process_taxonomy_nodes(session, taxonomy_id, data['nodes'])

            # Track Bronze to Silver mapping
            session.execute(
                text("""
                UPDATE silver_taxonomies
                SET bronze_taxonomy_id = :bronze_id
                WHERE taxonomy_id = :taxonomy_id
                """),
                {'bronze_id': bronze_id, 'taxonomy_id': taxonomy_id}
            )

        session.commit()
        return len(bronze_data)


def process_bronze_professions(source_id: int, customer_id: int) -> int:
    """Process profession data from Bronze to Silver"""
    with Session(engine) as session:
        # Get Bronze profession data
        bronze_data = session.execute(
            text("""
            SELECT bronze_id, row_json, type
            FROM bronze_professions
            WHERE source_id = :source_id
            """),
            {'source_id': source_id}
        ).fetchall()

        if not bronze_data:
            return 0

        # Process each Bronze record
        for bronze_id, row_json, load_type in bronze_data:
            data = json.loads(row_json) if isinstance(row_json, str) else row_json

            # Create or update profession in Silver
            profession_id = create_or_update_profession(session, customer_id, data, source_id)

            # Process attributes
            if 'attributes' in data:
                process_profession_attributes(session, profession_id, data['attributes'])
            else:
                # Extract attributes from flat structure
                extract_and_store_attributes(session, profession_id, data)

            # Track Bronze to Silver mapping
            session.execute(
                text("""
                UPDATE silver_professions
                SET bronze_profession_id = :bronze_id
                WHERE profession_id = :profession_id
                """),
                {'bronze_id': bronze_id, 'profession_id': profession_id}
            )

            # Track attribute combinations
            track_attribute_combination(session, customer_id, data)

        session.commit()
        return len(bronze_data)


def create_or_update_taxonomy(session: Session, customer_id: int,
                             data: Dict, source_id: int) -> int:
    """Create or update a taxonomy in Silver layer"""
    # Check if taxonomy exists
    existing = session.execute(
        text("""
        SELECT taxonomy_id FROM silver_taxonomies
        WHERE customer_id = :customer_id
        AND name = :name
        """),
        {'customer_id': customer_id, 'name': data.get('name', f'Taxonomy_{customer_id}')}
    ).fetchone()

    if existing:
        # Update existing
        taxonomy_id = existing[0]
        session.execute(
            text("""
            UPDATE silver_taxonomies
            SET status = :status,
                source_id = :source_id,
                last_updated_at = NOW()
            WHERE taxonomy_id = :taxonomy_id
            """),
            {
                'status': data.get('status', 'active'),
                'source_id': source_id,
                'taxonomy_id': taxonomy_id
            }
        )
    else:
        # Create new
        result = session.execute(
            text("""
            INSERT INTO silver_taxonomies
            (customer_id, name, type, status, source_id, created_at)
            VALUES (:customer_id, :name, 'customer', :status, :source_id, NOW())
            RETURNING taxonomy_id
            """),
            {
                'customer_id': customer_id,
                'name': data.get('name', f'Taxonomy_{customer_id}'),
                'status': data.get('status', 'active'),
                'source_id': source_id
            }
        )
        taxonomy_id = result.fetchone()[0]

    return taxonomy_id


def process_taxonomy_nodes(session: Session, taxonomy_id: int, nodes: List[Dict]):
    """Process taxonomy nodes and create hierarchy"""
    node_mapping = {}  # Map original IDs to new node_ids

    # Sort nodes by level if available
    nodes_sorted = sorted(nodes, key=lambda x: x.get('level', 0))

    for node_data in nodes_sorted:
        # Get or create node type
        node_type_id = get_or_create_node_type(
            session,
            node_data.get('type', 'profession'),
            node_data.get('level', 1)
        )

        # Determine parent_node_id
        parent_node_id = None
        if 'parent_id' in node_data and node_data['parent_id'] in node_mapping:
            parent_node_id = node_mapping[node_data['parent_id']]

        # Create node
        result = session.execute(
            text("""
            INSERT INTO silver_taxonomies_nodes
            (node_type_id, taxonomy_id, parent_node_id, value, created_at)
            VALUES (:node_type_id, :taxonomy_id, :parent_node_id, :value, NOW())
            RETURNING node_id
            """),
            {
                'node_type_id': node_type_id,
                'taxonomy_id': taxonomy_id,
                'parent_node_id': parent_node_id,
                'value': node_data.get('value', node_data.get('name', ''))
            }
        )
        node_id = result.fetchone()[0]

        # Store mapping for hierarchy
        if 'id' in node_data:
            node_mapping[node_data['id']] = node_id

        # Process node attributes
        if 'attributes' in node_data:
            for attr_name, attr_value in node_data['attributes'].items():
                create_node_attribute(session, node_id, attr_name, attr_value)


def get_or_create_node_type(session: Session, type_name: str, level: int) -> int:
    """Get or create a node type"""
    existing = session.execute(
        text("""
        SELECT node_type_id FROM silver_taxonomies_nodes_types
        WHERE name = :name AND level = :level
        """),
        {'name': type_name, 'level': level}
    ).fetchone()

    if existing:
        return existing[0]

    result = session.execute(
        text("""
        INSERT INTO silver_taxonomies_nodes_types
        (name, level, status, created_at)
        VALUES (:name, :level, 'active', NOW())
        RETURNING node_type_id
        """),
        {'name': type_name, 'level': level}
    )
    return result.fetchone()[0]


def create_node_attribute(session: Session, node_id: int, name: str, value: str):
    """Create a node attribute"""
    # Get or create attribute type
    attr_type_id = get_or_create_attribute_type(session, name)

    session.execute(
        text("""
        INSERT INTO silver_taxonomies_nodes_attributes
        (node_id, name, value, attribute_type_id, created_at)
        VALUES (:node_id, :name, :value, :attr_type_id, NOW())
        """),
        {
            'node_id': node_id,
            'name': name,
            'value': str(value),
            'attr_type_id': attr_type_id
        }
    )


def create_or_update_profession(session: Session, customer_id: int,
                               data: Dict, source_id: int) -> int:
    """Create or update a profession in Silver layer"""
    profession_name = data.get('profession_name') or data.get('profession_code', '')

    # Check if profession exists
    existing = session.execute(
        text("""
        SELECT profession_id FROM silver_professions
        WHERE customer_id = :customer_id
        AND name = :name
        """),
        {'customer_id': customer_id, 'name': profession_name}
    ).fetchone()

    if existing:
        # Update existing
        profession_id = existing[0]
        session.execute(
            text("""
            UPDATE silver_professions
            SET source_id = :source_id,
                last_updated_at = NOW()
            WHERE profession_id = :profession_id
            """),
            {'source_id': source_id, 'profession_id': profession_id}
        )
    else:
        # Create new
        result = session.execute(
            text("""
            INSERT INTO silver_professions
            (customer_id, name, source_id, created_at)
            VALUES (:customer_id, :name, :source_id, NOW())
            RETURNING profession_id
            """),
            {
                'customer_id': customer_id,
                'name': profession_name,
                'source_id': source_id
            }
        )
        profession_id = result.fetchone()[0]

    return profession_id


def process_profession_attributes(session: Session, profession_id: int, attributes: Dict):
    """Process explicit profession attributes"""
    for attr_name, attr_value in attributes.items():
        create_profession_attribute(session, profession_id, attr_name, attr_value)


def extract_and_store_attributes(session: Session, profession_id: int, data: Dict):
    """Extract attributes from flat profession data"""
    # Common attribute fields to extract
    attribute_fields = ['state', 'license_type', 'abbreviation', 'board_name',
                       'verification_method', 'issuing_authority']

    for field in attribute_fields:
        if field in data and data[field]:
            create_profession_attribute(session, profession_id, field, data[field])


def create_profession_attribute(session: Session, profession_id: int, name: str, value: str):
    """Create a profession attribute"""
    # Get or create attribute type
    attr_type_id = get_or_create_attribute_type(session, name)

    session.execute(
        text("""
        INSERT INTO silver_professions_attributes
        (profession_id, name, value, attribute_type_id, created_at)
        VALUES (:profession_id, :name, :value, :attr_type_id, NOW())
        ON CONFLICT (profession_id, name, value) DO NOTHING
        """),
        {
            'profession_id': profession_id,
            'name': name,
            'value': str(value),
            'attr_type_id': attr_type_id
        }
    )


def get_or_create_attribute_type(session: Session, name: str) -> Optional[int]:
    """Get or create an attribute type"""
    existing = session.execute(
        text("""
        SELECT attribute_type_id FROM silver_attribute_types
        WHERE attribute_name = :name
        """),
        {'name': name}
    ).fetchone()

    if existing:
        return existing[0]

    result = session.execute(
        text("""
        INSERT INTO silver_attribute_types
        (attribute_name, data_type, applies_to, created_at)
        VALUES (:name, 'string', 'both', NOW())
        RETURNING attribute_type_id
        """),
        {'name': name}
    )
    return result.fetchone()[0]


def track_attribute_combination(session: Session, customer_id: int, data: Dict):
    """Track unique attribute combinations for pattern analysis"""
    import hashlib

    # Extract key attributes
    state = data.get('state', '')
    profession_code = data.get('profession_code', '')
    profession_desc = data.get('profession_description', '')
    issuing_auth = data.get('issuing_authority', '')

    # Create hash of combination
    combo_str = f"{customer_id}|{state}|{profession_code}|{profession_desc}|{issuing_auth}"
    combo_hash = hashlib.md5(combo_str.encode()).hexdigest()

    # Check if combination exists
    existing = session.execute(
        text("""
        SELECT combination_id, occurrence_count
        FROM silver_attribute_combinations
        WHERE combination_hash = :hash
        """),
        {'hash': combo_hash}
    ).fetchone()

    if existing:
        # Update occurrence count and last seen
        session.execute(
            text("""
            UPDATE silver_attribute_combinations
            SET occurrence_count = occurrence_count + 1,
                last_seen_date = NOW()
            WHERE combination_id = :combo_id
            """),
            {'combo_id': existing[0]}
        )
    else:
        # Create new combination
        session.execute(
            text("""
            INSERT INTO silver_attribute_combinations
            (customer_id, state_code, profession_code, profession_description,
             issuing_authority, combination_hash, additional_attributes,
             first_seen_date, occurrence_count, mapping_status)
            VALUES (:customer_id, :state, :code, :desc, :auth, :hash,
                   :additional, NOW(), 1, 'pending')
            """),
            {
                'customer_id': customer_id,
                'state': state,
                'code': profession_code,
                'desc': profession_desc,
                'auth': issuing_auth,
                'hash': combo_hash,
                'additional': json.dumps({k: v for k, v in data.items()
                                         if k not in ['state', 'profession_code',
                                                     'profession_description',
                                                     'issuing_authority']})
            }
        )


def get_source_info(source_id: int) -> Optional[Dict]:
    """Get source information from bronze_data_sources"""
    with Session(engine) as session:
        result = session.execute(
            text("""
            SELECT source_id, customer_id, source_type, source_name
            FROM bronze_data_sources
            WHERE source_id = :source_id
            """),
            {'source_id': source_id}
        ).fetchone()

        if result:
            return {
                'source_id': result[0],
                'customer_id': result[1],
                'source_type': result[2],
                'source_name': result[3]
            }
        return None


def trigger_mapping_rules(source_id: int):
    """Send message to trigger mapping rules processing"""
    if not SQS_QUEUE_URL:
        logger.warning("MAPPING_RULES_QUEUE not configured")
        return

    message = {
        'source_id': source_id,
        'timestamp': datetime.now().isoformat(),
        'action': 'apply_mapping_rules'
    }

    try:
        response = sqs_client.send_message(
            QueueUrl=SQS_QUEUE_URL,
            MessageBody=json.dumps(message)
        )
        logger.info(f"Triggered mapping rules for source_id {source_id}")
    except Exception as e:
        logger.error(f"Failed to trigger mapping rules: {str(e)}")


def log_processing_start(source_id: int, stage: str):
    """Log start of processing stage"""
    with Session(engine) as session:
        session.execute(
            text("""
            INSERT INTO processing_log
            (source_id, stage, status, created_at)
            VALUES (:source_id, :stage, 'started', NOW())
            """),
            {'source_id': source_id, 'stage': stage}
        )
        session.commit()


def log_processing_complete(source_id: int, stage: str, records_processed: int):
    """Log completion of processing stage"""
    with Session(engine) as session:
        session.execute(
            text("""
            INSERT INTO processing_log
            (source_id, stage, status, records_processed, created_at)
            VALUES (:source_id, :stage, 'completed', :records, NOW())
            """),
            {'source_id': source_id, 'stage': stage, 'records': records_processed}
        )
        session.commit()


def log_processing_error(source_id: int, stage: str, error: str):
    """Log processing error"""
    with Session(engine) as session:
        session.execute(
            text("""
            INSERT INTO processing_log
            (source_id, stage, status, error_details, created_at)
            VALUES (:source_id, :stage, 'failed', :error, NOW())
            """),
            {
                'source_id': source_id,
                'stage': stage,
                'error': json.dumps({'error': error})
            }
        )
        session.commit()
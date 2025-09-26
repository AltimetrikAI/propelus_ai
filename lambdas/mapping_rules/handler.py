"""
Mapping Rules Lambda Handler
Processes Silver layer data through mapping rules to determine taxonomy mappings
"""
import json
import re
import os
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional
from decimal import Decimal
import boto3
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
from fuzzywuzzy import fuzz
import hashlib

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DATABASE_URL = os.environ.get('DATABASE_URL')
SQS_QUEUE_URL = os.environ.get('TRANSLATION_QUEUE')
BEDROCK_REGION = os.environ.get('AWS_REGION', 'us-east-1')

# AWS clients
sqs_client = boto3.client('sqs')
bedrock_client = boto3.client('bedrock-runtime', region_name=BEDROCK_REGION)

# Database connection
engine = None
if DATABASE_URL:
    engine = create_engine(DATABASE_URL)


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for mapping rules processing

    Event sources:
    - SQS messages from Silver processing
    - Direct invocation for specific source_id
    """
    try:
        if 'Records' in event:
            # SQS trigger
            return process_sqs_event(event)
        else:
            # Direct invocation
            return process_direct_invocation(event)

    except Exception as e:
        logger.error(f"Error processing mapping rules: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }


def process_sqs_event(event: Dict[str, Any]) -> Dict[str, Any]:
    """Process SQS messages"""
    results = []

    for record in event.get('Records', []):
        try:
            message = json.loads(record['body'])
            source_id = message.get('source_id')

            if not source_id:
                logger.error(f"No source_id in message: {message}")
                continue

            logger.info(f"Processing mapping rules for source_id: {source_id}")

            # Process taxonomies and professions
            taxonomy_results = process_taxonomy_mappings(source_id)
            profession_results = process_profession_mappings(source_id)

            results.append({
                'source_id': source_id,
                'taxonomy_mappings': taxonomy_results,
                'profession_mappings': profession_results,
                'status': 'success'
            })

        except Exception as e:
            logger.error(f"Error processing record: {str(e)}")
            results.append({
                'source_id': source_id if 'source_id' in locals() else 'unknown',
                'status': 'failed',
                'error': str(e)
            })

    return {
        'statusCode': 200,
        'body': json.dumps({'results': results})
    }


def process_direct_invocation(event: Dict[str, Any]) -> Dict[str, Any]:
    """Process direct Lambda invocation"""
    source_id = event.get('source_id')
    mapping_type = event.get('type', 'both')  # 'taxonomy', 'profession', 'both'

    if not source_id:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'source_id is required'})
        }

    results = {}

    if mapping_type in ['taxonomy', 'both']:
        results['taxonomy_mappings'] = process_taxonomy_mappings(source_id)

    if mapping_type in ['profession', 'both']:
        results['profession_mappings'] = process_profession_mappings(source_id)

    return {
        'statusCode': 200,
        'body': json.dumps(results)
    }


def process_taxonomy_mappings(source_id: int) -> Dict[str, Any]:
    """Process taxonomy-to-taxonomy mappings using rules"""
    logger.info(f"Processing taxonomy mappings for source_id: {source_id}")

    with Session(engine) as session:
        # Get all customer nodes that need mapping
        query = text("""
            SELECT n.node_id, n.node_type_id, n.value, n.taxonomy_id,
                   nt.name as node_type_name, nt.level,
                   t.customer_id, t.name as taxonomy_name
            FROM silver_taxonomies_nodes n
            JOIN silver_taxonomies_nodes_types nt ON n.node_type_id = nt.node_type_id
            JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
            WHERE NOT EXISTS (
                SELECT 1 FROM silver_mapping_taxonomies mt
                WHERE mt.node_id = n.node_id AND mt.status = 'active'
            )
            AND t.type = 'customer'
            ORDER BY nt.level, n.node_id
        """)

        unmapped_nodes = session.execute(query).fetchall()

        results = {
            'nodes_processed': len(unmapped_nodes),
            'mappings_created': 0,
            'high_confidence': 0,
            'needs_review': 0,
            'failed': 0
        }

        for node in unmapped_nodes:
            try:
                # Get rules for this node type
                rules = get_mapping_rules_for_node_type(session, node.node_type_id, 'taxonomy')

                # Try to find mapping using rules
                mapping_result = apply_mapping_rules(
                    session,
                    node,
                    rules,
                    rule_type='taxonomy'
                )

                if mapping_result:
                    results['mappings_created'] += 1
                    if mapping_result['confidence'] >= 90:
                        results['high_confidence'] += 1
                    else:
                        results['needs_review'] += 1
                else:
                    results['failed'] += 1

            except Exception as e:
                logger.error(f"Error processing node {node.node_id}: {str(e)}")
                results['failed'] += 1

    return results


def process_profession_mappings(source_id: int) -> Dict[str, Any]:
    """Process profession-to-taxonomy mappings using rules"""
    logger.info(f"Processing profession mappings for source_id: {source_id}")

    with Session(engine) as session:
        # Get professions that need mapping
        query = text("""
            SELECT p.profession_id, p.customer_id, p.name as profession_name,
                   COALESCE(
                       json_object_agg(pa.name, pa.value) FILTER (WHERE pa.name IS NOT NULL),
                       '{}'::json
                   ) as attributes
            FROM silver_professions p
            LEFT JOIN silver_professions_attributes pa ON p.profession_id = pa.profession_id
            WHERE NOT EXISTS (
                SELECT 1 FROM silver_mapping_professions mp
                WHERE mp.profession_id = p.profession_id AND mp.status = 'active'
            )
            GROUP BY p.profession_id, p.customer_id, p.name
            ORDER BY p.profession_id
        """)

        unmapped_professions = session.execute(query).fetchall()

        results = {
            'professions_processed': len(unmapped_professions),
            'mappings_created': 0,
            'high_confidence': 0,
            'needs_review': 0,
            'failed': 0
        }

        for profession in unmapped_professions:
            try:
                # Apply context rules first (ACLS, ARRT, etc.)
                context_mapping = apply_context_rules(session, profession)

                if context_mapping:
                    # Store context-based mapping
                    store_profession_mapping(session, profession, context_mapping)
                    results['mappings_created'] += 1
                    results['high_confidence'] += 1
                else:
                    # Try general profession mapping rules
                    rules = get_profession_mapping_rules(session)
                    mapping_result = apply_profession_rules(session, profession, rules)

                    if mapping_result:
                        results['mappings_created'] += 1
                        if mapping_result['confidence'] >= 90:
                            results['high_confidence'] += 1
                        else:
                            results['needs_review'] += 1
                    else:
                        results['failed'] += 1

            except Exception as e:
                logger.error(f"Error processing profession {profession.profession_id}: {str(e)}")
                results['failed'] += 1

    return results


def get_mapping_rules_for_node_type(session: Session, node_type_id: int, rule_context: str) -> List[Dict]:
    """Get mapping rules for a specific node type"""
    query = text("""
        SELECT r.mapping_rule_id, r.name, r.pattern, r.attributes, r.flags, r.action,
               rt.name as rule_type_name, rt.command, rt.ai_mapping_flag,
               ra.priority
        FROM silver_mapping_taxonomies_rules r
        JOIN silver_mapping_taxonomies_rules_types rt ON r.mapping_rule_type_id = rt.mapping_rule_type_id
        JOIN silver_mapping_taxonomies_rules_assignment ra ON r.mapping_rule_id = ra.mapping_rule_id
        WHERE ra.node_type_id = :node_type_id
        AND r.enabled = true
        AND ra.enabled = true
        ORDER BY ra.priority ASC
    """)

    result = session.execute(query, {'node_type_id': node_type_id})
    return [dict(row) for row in result.fetchall()]


def apply_mapping_rules(session: Session, node: Any, rules: List[Dict], rule_type: str) -> Optional[Dict]:
    """Apply mapping rules to find the best match"""

    for rule in rules:
        try:
            confidence = 0
            target_node_id = None

            if rule['command'] == 'exact_match':
                target_node_id, confidence = apply_exact_match_rule(session, node, rule)
            elif rule['command'] == 'regex_match':
                target_node_id, confidence = apply_regex_rule(session, node, rule)
            elif rule['command'] == 'fuzzy_match':
                target_node_id, confidence = apply_fuzzy_rule(session, node, rule)
            elif rule['command'] == 'ai_semantic':
                target_node_id, confidence = apply_ai_rule(session, node, rule)

            if target_node_id and confidence > 0:
                # Store the mapping
                mapping_id = store_taxonomy_mapping(
                    session,
                    rule['mapping_rule_id'],
                    node.node_id,
                    target_node_id,
                    confidence
                )

                return {
                    'mapping_id': mapping_id,
                    'rule_id': rule['mapping_rule_id'],
                    'rule_name': rule['name'],
                    'confidence': confidence,
                    'target_node_id': target_node_id
                }

        except Exception as e:
            logger.error(f"Error applying rule {rule['name']}: {str(e)}")
            continue

    return None


def apply_exact_match_rule(session: Session, node: Any, rule: Dict) -> tuple[Optional[int], float]:
    """Apply exact match rule"""
    # Find exact matches in master taxonomy
    query = text("""
        SELECT n.node_id, n.value
        FROM silver_taxonomies_nodes n
        JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
        WHERE t.type = 'master'
        AND LOWER(n.value) = LOWER(:node_value)
        LIMIT 1
    """)

    result = session.execute(query, {'node_value': node.value})
    match = result.fetchone()

    if match:
        return match.node_id, 100.0

    return None, 0.0


def apply_regex_rule(session: Session, node: Any, rule: Dict) -> tuple[Optional[int], float]:
    """Apply regex pattern matching rule"""
    if not rule['pattern']:
        return None, 0.0

    try:
        pattern = re.compile(rule['pattern'], re.IGNORECASE)

        if pattern.search(node.value):
            # Find master taxonomy nodes that match the action pattern
            if rule['action']:
                query = text("""
                    SELECT n.node_id, n.value
                    FROM silver_taxonomies_nodes n
                    JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
                    WHERE t.type = 'master'
                    AND n.value ~* :action_pattern
                    ORDER BY LENGTH(n.value)
                    LIMIT 1
                """)

                result = session.execute(query, {'action_pattern': rule['action']})
                match = result.fetchone()

                if match:
                    return match.node_id, 95.0

    except Exception as e:
        logger.error(f"Regex error: {str(e)}")

    return None, 0.0


def apply_fuzzy_rule(session: Session, node: Any, rule: Dict) -> tuple[Optional[int], float]:
    """Apply fuzzy string matching rule"""
    # Get all master nodes of similar type
    query = text("""
        SELECT n.node_id, n.value
        FROM silver_taxonomies_nodes n
        JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
        WHERE t.type = 'master'
    """)

    result = session.execute(query)
    master_nodes = result.fetchall()

    best_match = None
    best_score = 0

    for master_node in master_nodes:
        # Calculate fuzzy match score
        score = fuzz.ratio(node.value.lower(), master_node.value.lower())

        if score > best_score and score >= 80:  # Minimum threshold
            best_score = score
            best_match = master_node

    if best_match and best_score >= 80:
        return best_match.node_id, float(best_score)

    return None, 0.0


def apply_ai_rule(session: Session, node: Any, rule: Dict) -> tuple[Optional[int], float]:
    """Apply AI/LLM semantic matching (placeholder for future implementation)"""
    # This would use AWS Bedrock for semantic matching
    # For now, return None to indicate AI processing needed
    logger.info(f"AI rule flagged for node {node.node_id}: {node.value}")
    return None, 0.0


def apply_context_rules(session: Session, profession: Any) -> Optional[Dict]:
    """Apply context rules for profession mapping (ACLS, ARRT, etc.)"""
    attributes = profession.attributes if hasattr(profession, 'attributes') else {}
    profession_name = profession.profession_name.upper()

    # Check for known context patterns
    context_mappings = {
        'ACLS': 'American Heart Association',
        'BLS': 'American Heart Association',
        'PALS': 'American Heart Association',
        'ARRT': 'American Registry of Radiologic Technologists',
        'NRP': 'American Academy of Pediatrics'
    }

    for acronym, authority in context_mappings.items():
        if acronym in profession_name:
            # Find the corresponding node in master taxonomy
            query = text("""
                SELECT n.node_id
                FROM silver_taxonomies_nodes n
                JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
                WHERE t.type = 'master'
                AND n.value ILIKE :authority
                LIMIT 1
            """)

            result = session.execute(query, {'authority': f'%{authority}%'})
            match = result.fetchone()

            if match:
                return {
                    'node_id': match.node_id,
                    'confidence': 100.0,
                    'rule_type': 'context',
                    'context_key': acronym,
                    'authority': authority
                }

    return None


def get_profession_mapping_rules(session: Session) -> List[Dict]:
    """Get profession mapping rules"""
    query = text("""
        SELECT r.mapping_rule_id, r.name, r.pattern, r.attributes, r.flags, r.action,
               rt.name as rule_type_name, rt.command
        FROM silver_mapping_professions_rules r
        JOIN silver_mapping_professions_rules_types rt ON r.mapping_rule_type_id = rt.mapping_rule_type_id
        WHERE r.enabled = true
        ORDER BY r.mapping_rule_id
    """)

    result = session.execute(query)
    return [dict(row) for row in result.fetchall()]


def apply_profession_rules(session: Session, profession: Any, rules: List[Dict]) -> Optional[Dict]:
    """Apply rules to map profession to taxonomy node"""
    # Similar to taxonomy rules but for professions
    # Implementation would be similar to apply_mapping_rules
    return None  # Placeholder


def store_taxonomy_mapping(session: Session, rule_id: int, node_id: int, target_node_id: int, confidence: float) -> int:
    """Store taxonomy mapping in silver_mapping_taxonomies"""
    # Note: Updated to use target_node_id instead of master_node_id for flexibility
    query = text("""
        INSERT INTO silver_mapping_taxonomies
        (mapping_rule_id, master_node_id, node_id, confidence, status, created_at)
        VALUES (:rule_id, :target_node_id, :node_id, :confidence,
                CASE WHEN :confidence >= 90 THEN 'active' ELSE 'pending_review' END,
                NOW())
        RETURNING mapping_id
    """)

    result = session.execute(query, {
        'rule_id': rule_id,
        'target_node_id': target_node_id,
        'node_id': node_id,
        'confidence': confidence
    })

    session.commit()
    return result.fetchone()[0]


def store_profession_mapping(session: Session, profession: Any, mapping_result: Dict) -> int:
    """Store profession mapping in silver_mapping_professions"""
    # First, create a dummy rule for context mappings
    rule_id = get_or_create_context_rule(session, mapping_result.get('rule_type', 'context'))

    query = text("""
        INSERT INTO silver_mapping_professions
        (mapping_rule_id, node_id, profession_id, status, created_at)
        VALUES (:rule_id, :node_id, :profession_id, 'active', NOW())
        RETURNING mapping_id
    """)

    result = session.execute(query, {
        'rule_id': rule_id,
        'node_id': mapping_result['node_id'],
        'profession_id': profession.profession_id
    })

    session.commit()
    return result.fetchone()[0]


def get_or_create_context_rule(session: Session, rule_type: str) -> int:
    """Get or create a rule for context-based mappings"""
    # Check if rule exists
    query = text("""
        SELECT mapping_rule_id FROM silver_mapping_professions_rules
        WHERE name = :name
    """)

    result = session.execute(query, {'name': f'Context Rule - {rule_type}'})
    existing = result.fetchone()

    if existing:
        return existing.mapping_rule_id

    # Create new rule
    query = text("""
        INSERT INTO silver_mapping_professions_rules
        (mapping_rule_type_id, name, enabled, pattern, action, created_at)
        VALUES (1, :name, true, :pattern, 'context_mapping', NOW())
        RETURNING mapping_rule_id
    """)

    result = session.execute(query, {
        'name': f'Context Rule - {rule_type}',
        'pattern': f'{rule_type} context mapping'
    })

    session.commit()
    return result.fetchone()[0]


def create_processing_log(source_id: int, stage: str, status: str,
                         records_processed: int = 0, error_details: Dict = None):
    """Create entry in processing_log table"""
    with Session(engine) as session:
        query = text("""
        INSERT INTO processing_log
        (source_id, stage, status, records_processed, error_details, created_at)
        VALUES (:source_id, :stage, :status, :records_processed, :error_details, NOW())
        """)

        session.execute(query, {
            'source_id': source_id,
            'stage': stage,
            'status': status,
            'records_processed': records_processed,
            'error_details': json.dumps(error_details) if error_details else None
        })
        session.commit()
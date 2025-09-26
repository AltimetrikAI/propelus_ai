"""
Translation Lambda Handler
Provides real-time translation between taxonomies using Gold layer mappings
"""
import json
import os
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional, Union
import boto3
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session
import hashlib

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Environment variables
DATABASE_URL = os.environ.get('DATABASE_URL')
REDIS_URL = os.environ.get('REDIS_URL')

# AWS clients
if REDIS_URL:
    import redis
    redis_client = redis.from_url(REDIS_URL, decode_responses=True)
else:
    redis_client = None

# Database connection
engine = None
if DATABASE_URL:
    engine = create_engine(DATABASE_URL)


def handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler for translation service

    Event sources:
    - API Gateway requests
    - Direct invocation
    """
    try:
        if 'httpMethod' in event:
            # API Gateway trigger
            return process_api_request(event)
        else:
            # Direct invocation
            return process_direct_invocation(event)

    except Exception as e:
        logger.error(f"Error processing translation request: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }


def process_api_request(event: Dict[str, Any]) -> Dict[str, Any]:
    """Process API Gateway request"""
    try:
        body = json.loads(event.get('body', '{}'))

        # Extract translation request parameters
        source_taxonomy = body.get('source_taxonomy')
        target_taxonomy = body.get('target_taxonomy')
        source_code = body.get('source_code')
        attributes = body.get('attributes', {})
        options = body.get('options', {})

        if not all([source_taxonomy, target_taxonomy, source_code]):
            return {
                'statusCode': 400,
                'headers': {'Content-Type': 'application/json'},
                'body': json.dumps({
                    'error': 'Missing required fields: source_taxonomy, target_taxonomy, source_code'
                })
            }

        # Perform translation
        translation_result = translate_code(
            source_taxonomy,
            target_taxonomy,
            source_code,
            attributes,
            options
        )

        # Log translation pattern
        log_translation_pattern(
            source_taxonomy,
            target_taxonomy,
            source_code,
            attributes,
            translation_result
        )

        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps(translation_result)
        }

    except Exception as e:
        logger.error(f"Error processing API request: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({'error': str(e)})
        }


def process_direct_invocation(event: Dict[str, Any]) -> Dict[str, Any]:
    """Process direct Lambda invocation"""
    source_taxonomy = event.get('source_taxonomy')
    target_taxonomy = event.get('target_taxonomy')
    source_code = event.get('source_code')
    attributes = event.get('attributes', {})
    options = event.get('options', {})

    if not all([source_taxonomy, target_taxonomy, source_code]):
        return {
            'statusCode': 400,
            'body': json.dumps({
                'error': 'Missing required fields: source_taxonomy, target_taxonomy, source_code'
            })
        }

    translation_result = translate_code(
        source_taxonomy,
        target_taxonomy,
        source_code,
        attributes,
        options
    )

    return {
        'statusCode': 200,
        'body': json.dumps(translation_result)
    }


def translate_code(
    source_taxonomy: str,
    target_taxonomy: str,
    source_code: str,
    attributes: Dict[str, Any],
    options: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Translate a code from source taxonomy to target taxonomy
    """
    logger.info(f"Translating '{source_code}' from {source_taxonomy} to {target_taxonomy}")

    # Check cache first
    cache_key = generate_cache_key(source_taxonomy, target_taxonomy, source_code, attributes)
    cached_result = get_cached_translation(cache_key)

    if cached_result:
        logger.info(f"Cache hit for translation: {cache_key}")
        return cached_result

    # Perform translation lookup
    translation_result = perform_translation(
        source_taxonomy,
        target_taxonomy,
        source_code,
        attributes,
        options
    )

    # Cache the result
    if translation_result.get('matches'):
        cache_translation_result(cache_key, translation_result)

    return translation_result


def perform_translation(
    source_taxonomy: str,
    target_taxonomy: str,
    source_code: str,
    attributes: Dict[str, Any],
    options: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Perform the actual translation using database lookups
    """
    with Session(engine) as session:
        # Step 1: Find the source node
        source_node = find_source_node(session, source_taxonomy, source_code, attributes)

        if not source_node:
            return {
                'source_taxonomy': source_taxonomy,
                'target_taxonomy': target_taxonomy,
                'source_code': source_code,
                'matches': [],
                'status': 'no_source_match',
                'message': f'Source code "{source_code}" not found in taxonomy "{source_taxonomy}"'
            }

        # Step 2: Find mappings from source to target
        if target_taxonomy.lower() == 'master':
            # Source to Master mapping
            mappings = find_source_to_master_mappings(session, source_node['node_id'])
        elif source_taxonomy.lower() == 'master':
            # Master to Target mapping
            mappings = find_master_to_target_mappings(session, source_node['node_id'], target_taxonomy)
        else:
            # Source to Target via Master (two-hop)
            mappings = find_source_to_target_via_master(session, source_node['node_id'], target_taxonomy)

        if not mappings:
            return {
                'source_taxonomy': source_taxonomy,
                'target_taxonomy': target_taxonomy,
                'source_code': source_code,
                'source_match': source_node,
                'matches': [],
                'status': 'no_target_match',
                'message': f'No mappings found from "{source_taxonomy}" to "{target_taxonomy}"'
            }

        # Step 3: Apply context rules and filtering
        filtered_mappings = apply_context_filtering(session, mappings, attributes)

        # Step 4: Apply issuing authority overrides
        final_mappings = apply_authority_overrides(session, filtered_mappings, attributes)

        # Step 5: Format response with master taxonomy information
        include_alternatives = options.get('include_alternatives', False)
        min_confidence = options.get('min_confidence', 0.0)

        formatted_mappings = format_mappings(final_mappings, include_alternatives, min_confidence)

        # Extract master taxonomy nodes from mappings for transparency
        master_nodes = []
        for mapping in final_mappings:
            if mapping.get('via_master_node_id'):
                master_nodes.append({
                    'node_id': mapping.get('via_master_node_id'),
                    'confidence': mapping.get('source_to_master_confidence', 0)
                })

        return {
            'request_id': context.request_id if 'context' in locals() else None,
            'source_taxonomy': source_taxonomy,
            'target_taxonomy': target_taxonomy,
            'source_code': source_code,
            'source_match': source_node,
            'master_taxonomy_match': master_nodes[0] if master_nodes else None,  # Include master node
            'matches': formatted_mappings,
            'status': 'success',
            'total_matches': len(formatted_mappings),
            'timestamp': datetime.utcnow().isoformat()
        }


def find_source_node(
    session: Session,
    taxonomy_name: str,
    source_code: str,
    attributes: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    """Find the source node in the specified taxonomy"""

    # Handle special taxonomy names
    if taxonomy_name.lower() == 'master':
        taxonomy_condition = "t.type = 'master'"
        taxonomy_params = {}
    elif taxonomy_name.startswith('customer_'):
        customer_id = int(taxonomy_name.split('_')[1])
        taxonomy_condition = "t.customer_id = :customer_id AND t.type = 'customer'"
        taxonomy_params = {'customer_id': customer_id}
    else:
        taxonomy_condition = "t.name = :taxonomy_name"
        taxonomy_params = {'taxonomy_name': taxonomy_name}

    # Try exact match first
    query = text(f"""
        SELECT n.node_id, n.value, n.node_type_id, nt.name as node_type_name,
               t.taxonomy_id, t.name as taxonomy_name, t.customer_id
        FROM silver_taxonomies_nodes n
        JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
        JOIN silver_taxonomies_nodes_types nt ON n.node_type_id = nt.node_type_id
        WHERE {taxonomy_condition}
        AND (LOWER(n.value) = LOWER(:source_code)
             OR n.value ILIKE :source_code_pattern)
        LIMIT 1
    """)

    params = {
        **taxonomy_params,
        'source_code': source_code,
        'source_code_pattern': f'%{source_code}%'
    }

    result = session.execute(query, params)
    match = result.fetchone()

    if match:
        return {
            'node_id': match.node_id,
            'value': match.value,
            'node_type_id': match.node_type_id,
            'node_type_name': match.node_type_name,
            'taxonomy_id': match.taxonomy_id,
            'taxonomy_name': match.taxonomy_name,
            'customer_id': match.customer_id
        }

    # If no direct match, try profession lookup
    if taxonomy_name.startswith('customer_'):
        return find_profession_node(session, int(taxonomy_name.split('_')[1]), source_code, attributes)

    return None


def find_profession_node(
    session: Session,
    customer_id: int,
    source_code: str,
    attributes: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    """Find a profession that matches the source code and attributes"""

    query = text("""
        SELECT p.profession_id, p.name, p.customer_id,
               mp.node_id, n.value as taxonomy_value,
               nt.name as node_type_name
        FROM silver_professions p
        JOIN silver_mapping_professions mp ON p.profession_id = mp.profession_id
        JOIN silver_taxonomies_nodes n ON mp.node_id = n.node_id
        JOIN silver_taxonomies_nodes_types nt ON n.node_type_id = nt.node_type_id
        WHERE p.customer_id = :customer_id
        AND (LOWER(p.name) = LOWER(:source_code)
             OR p.name ILIKE :source_code_pattern)
        AND mp.status = 'active'
        LIMIT 1
    """)

    result = session.execute(query, {
        'customer_id': customer_id,
        'source_code': source_code,
        'source_code_pattern': f'%{source_code}%'
    })

    match = result.fetchone()

    if match:
        return {
            'node_id': match.node_id,
            'value': match.taxonomy_value,
            'node_type_name': match.node_type_name,
            'profession_id': match.profession_id,
            'profession_name': match.name,
            'customer_id': match.customer_id,
            'source_type': 'profession'
        }

    return None


def find_source_to_master_mappings(session: Session, source_node_id: int) -> List[Dict[str, Any]]:
    """Find mappings from source node to master taxonomy"""

    query = text("""
        SELECT gm.mapping_id, gm.master_node_id as target_node_id,
               n.value as target_value, nt.name as target_node_type,
               100.0 as confidence, 'gold' as layer
        FROM gold_taxonomies_mapping gm
        JOIN silver_taxonomies_nodes n ON gm.master_node_id = n.node_id
        JOIN silver_taxonomies_nodes_types nt ON n.node_type_id = nt.node_type_id
        WHERE gm.node_id = :source_node_id

        UNION ALL

        SELECT sm.mapping_id, sm.master_node_id as target_node_id,
               n.value as target_value, nt.name as target_node_type,
               COALESCE(sm.confidence, 0.0) as confidence, 'silver' as layer
        FROM silver_mapping_taxonomies sm
        JOIN silver_taxonomies_nodes n ON sm.master_node_id = n.node_id
        JOIN silver_taxonomies_nodes_types nt ON n.node_type_id = nt.node_type_id
        WHERE sm.node_id = :source_node_id
        AND sm.status = 'active'
        AND sm.confidence >= 70.0

        ORDER BY confidence DESC, layer ASC
    """)

    result = session.execute(query, {'source_node_id': source_node_id})
    return [dict(row) for row in result.fetchall()]


def find_master_to_target_mappings(session: Session, master_node_id: int, target_taxonomy: str) -> List[Dict[str, Any]]:
    """Find mappings from master node to target taxonomy"""

    # Handle target taxonomy identification
    if target_taxonomy.startswith('customer_'):
        customer_id = int(target_taxonomy.split('_')[1])
        taxonomy_condition = "t.customer_id = :customer_id AND t.type = 'customer'"
        taxonomy_params = {'customer_id': customer_id}
    else:
        taxonomy_condition = "t.name = :taxonomy_name"
        taxonomy_params = {'taxonomy_name': target_taxonomy}

    query = text(f"""
        SELECT gm.mapping_id, gm.node_id as target_node_id,
               n.value as target_value, nt.name as target_node_type,
               100.0 as confidence, 'gold' as layer,
               t.name as target_taxonomy_name
        FROM gold_taxonomies_mapping gm
        JOIN silver_taxonomies_nodes n ON gm.node_id = n.node_id
        JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
        JOIN silver_taxonomies_nodes_types nt ON n.node_type_id = nt.node_type_id
        WHERE gm.master_node_id = :master_node_id
        AND {taxonomy_condition}

        UNION ALL

        SELECT sm.mapping_id, sm.node_id as target_node_id,
               n.value as target_value, nt.name as target_node_type,
               COALESCE(sm.confidence, 0.0) as confidence, 'silver' as layer,
               t.name as target_taxonomy_name
        FROM silver_mapping_taxonomies sm
        JOIN silver_taxonomies_nodes n ON sm.node_id = n.node_id
        JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
        JOIN silver_taxonomies_nodes_types nt ON n.node_type_id = nt.node_type_id
        WHERE sm.master_node_id = :master_node_id
        AND {taxonomy_condition}
        AND sm.status = 'active'
        AND sm.confidence >= 70.0

        ORDER BY confidence DESC, layer ASC
    """)

    params = {
        'master_node_id': master_node_id,
        **taxonomy_params
    }

    result = session.execute(query, params)
    return [dict(row) for row in result.fetchall()]


def find_source_to_target_via_master(
    session: Session,
    source_node_id: int,
    target_taxonomy: str
) -> List[Dict[str, Any]]:
    """Find mappings from source to target via master taxonomy (two-hop)"""

    # First hop: source to master
    master_mappings = find_source_to_master_mappings(session, source_node_id)

    all_target_mappings = []

    # Second hop: master to target for each master node found
    for master_mapping in master_mappings:
        target_mappings = find_master_to_target_mappings(
            session,
            master_mapping['target_node_id'],
            target_taxonomy
        )

        # Combine confidence scores (multiply probabilities)
        for target_mapping in target_mappings:
            combined_confidence = (master_mapping['confidence'] * target_mapping['confidence']) / 100.0
            target_mapping['confidence'] = combined_confidence
            target_mapping['via_master_node_id'] = master_mapping['target_node_id']
            target_mapping['source_to_master_confidence'] = master_mapping['confidence']
            target_mapping['master_to_target_confidence'] = target_mapping['confidence']

        all_target_mappings.extend(target_mappings)

    # Sort by confidence and return unique mappings
    unique_mappings = {}
    for mapping in all_target_mappings:
        key = mapping['target_node_id']
        if key not in unique_mappings or mapping['confidence'] > unique_mappings[key]['confidence']:
            unique_mappings[key] = mapping

    return sorted(unique_mappings.values(), key=lambda x: x['confidence'], reverse=True)


def apply_context_filtering(
    session: Session,
    mappings: List[Dict[str, Any]],
    attributes: Dict[str, Any]
) -> List[Dict[str, Any]]:
    """Apply context rules to filter mappings"""

    # Get active context rules
    query = text("""
        SELECT rule_id, rule_name, rule_type, pattern, context_key, context_value,
               authority_id, priority, override_state, notes
        FROM silver_context_rules
        WHERE is_active = true
        ORDER BY priority ASC
    """)

    result = session.execute(query)
    context_rules = [dict(row) for row in result.fetchall()]

    # Apply each rule
    for rule in context_rules:
        mappings = apply_single_context_rule(mappings, rule, attributes)

    return mappings


def apply_single_context_rule(
    mappings: List[Dict[str, Any]],
    rule: Dict[str, Any],
    attributes: Dict[str, Any]
) -> List[Dict[str, Any]]:
    """Apply a single context rule"""

    if rule['rule_type'] == 'abbreviation':
        # Handle abbreviation expansion (ACLS -> American Heart Association)
        for mapping in mappings:
            if rule['pattern'].upper() in mapping.get('target_value', '').upper():
                mapping['context_applied'] = rule['rule_name']
                mapping['confidence'] = min(100.0, mapping['confidence'] + 5.0)  # Boost confidence

    elif rule['rule_type'] == 'override':
        # Handle state overrides for national certifications
        state_code = attributes.get('state', '')
        if rule['override_state'] and state_code:
            # Remove state-specific mappings for national certs
            mappings = [m for m in mappings if not ('state' in m.get('target_value', '').lower())]

    elif rule['rule_type'] == 'disambiguation':
        # Handle cases where context helps choose between multiple matches
        context_value = attributes.get(rule['context_key'])
        if context_value and context_value.lower() == rule['context_value'].lower():
            for mapping in mappings:
                if rule['pattern'] in mapping.get('target_value', ''):
                    mapping['confidence'] = min(100.0, mapping['confidence'] + 10.0)

    return mappings


def apply_authority_overrides(
    session: Session,
    mappings: List[Dict[str, Any]],
    attributes: Dict[str, Any]
) -> List[Dict[str, Any]]:
    """Apply issuing authority overrides"""

    issuing_authority = attributes.get('issuing_authority', '')

    if not issuing_authority:
        return mappings

    # Get authority information
    query = text("""
        SELECT authority_id, authority_name, authority_type, state_code,
               override_state_mapping, is_national
        FROM silver_issuing_authorities
        WHERE LOWER(authority_name) = LOWER(:authority_name)
        OR authority_name ILIKE :authority_pattern
    """)

    result = session.execute(query, {
        'authority_name': issuing_authority,
        'authority_pattern': f'%{issuing_authority}%'
    })

    authority = result.fetchone()

    if authority and authority.is_national:
        # For national authorities, filter out state-specific mappings
        mappings = [m for m in mappings if not is_state_specific_mapping(m)]

        # Boost confidence for national mappings
        for mapping in mappings:
            mapping['authority_override'] = True
            mapping['confidence'] = min(100.0, mapping['confidence'] + 10.0)

    return mappings


def is_state_specific_mapping(mapping: Dict[str, Any]) -> bool:
    """Check if a mapping is state-specific"""
    target_value = mapping.get('target_value', '').lower()

    # Common state indicators
    state_indicators = ['state', 'licensed', 'board', 'department']

    return any(indicator in target_value for indicator in state_indicators)


def format_mappings(
    mappings: List[Dict[str, Any]],
    include_alternatives: bool,
    min_confidence: float
) -> List[Dict[str, Any]]:
    """Format mappings for response"""

    # Filter by minimum confidence
    filtered_mappings = [m for m in mappings if m['confidence'] >= min_confidence]

    # Limit results if not including alternatives
    if not include_alternatives and filtered_mappings:
        filtered_mappings = [filtered_mappings[0]]  # Return only the best match

    # Format each mapping with complete node information
    formatted = []
    for mapping in filtered_mappings:
        formatted_mapping = {
            'target_code': mapping['target_value'],
            'target_node_id': mapping['target_node_id'],
            'confidence': round(mapping['confidence'], 2),
            'layer': mapping.get('layer', 'unknown'),
            'node_type': mapping.get('target_node_type'),
            # Include all attributes from the node
            'attributes': mapping.get('attributes', {}),
            'taxonomy_name': mapping.get('target_taxonomy_name', ''),
            'full_node_data': {
                'node_id': mapping['target_node_id'],
                'value': mapping['target_value'],
                'type': mapping.get('target_node_type'),
                'attributes': mapping.get('attributes', {})
            }
        }

        # Add optional fields
        if mapping.get('context_applied'):
            formatted_mapping['context_rule'] = mapping['context_applied']

        if mapping.get('authority_override'):
            formatted_mapping['authority_override'] = True

        if mapping.get('via_master_node_id'):
            formatted_mapping['via_master'] = True
            formatted_mapping['master_node_id'] = mapping['via_master_node_id']
            formatted_mapping['translation_path'] = {
                'source_to_master_confidence': mapping.get('source_to_master_confidence', 0),
                'master_to_target_confidence': mapping.get('master_to_target_confidence', 0)
            }

        formatted.append(formatted_mapping)

    return formatted


def generate_cache_key(
    source_taxonomy: str,
    target_taxonomy: str,
    source_code: str,
    attributes: Dict[str, Any]
) -> str:
    """Generate cache key for translation"""

    # Sort attributes for consistent key generation
    sorted_attrs = json.dumps(attributes, sort_keys=True)

    key_string = f"{source_taxonomy}:{target_taxonomy}:{source_code}:{sorted_attrs}"

    return f"translation:{hashlib.md5(key_string.encode()).hexdigest()}"


def get_cached_translation(cache_key: str) -> Optional[Dict[str, Any]]:
    """Get cached translation result"""

    if not redis_client:
        return None

    try:
        cached_data = redis_client.get(cache_key)
        if cached_data:
            return json.loads(cached_data)
    except Exception as e:
        logger.warning(f"Cache read error: {str(e)}")

    return None


def cache_translation_result(cache_key: str, result: Dict[str, Any], ttl: int = 3600):
    """Cache translation result"""

    if not redis_client:
        return

    try:
        redis_client.setex(cache_key, ttl, json.dumps(result))
    except Exception as e:
        logger.warning(f"Cache write error: {str(e)}")


def log_translation_pattern(
    source_taxonomy: str,
    target_taxonomy: str,
    source_code: str,
    attributes: Dict[str, Any],
    result: Dict[str, Any]
):
    """Log translation pattern for analytics"""

    with Session(engine) as session:
        try:
            # Get taxonomy IDs
            source_taxonomy_id = get_taxonomy_id(session, source_taxonomy)
            target_taxonomy_id = get_taxonomy_id(session, target_taxonomy)

            if not source_taxonomy_id or not target_taxonomy_id:
                return

            # Check if pattern exists
            query = text("""
                SELECT pattern_id, request_count
                FROM silver_translation_patterns
                WHERE source_taxonomy_id = :source_taxonomy_id
                AND target_taxonomy_id = :target_taxonomy_id
                AND source_code = :source_code
                AND source_attributes = :attributes
            """)

            result_check = session.execute(query, {
                'source_taxonomy_id': source_taxonomy_id,
                'target_taxonomy_id': target_taxonomy_id,
                'source_code': source_code,
                'attributes': json.dumps(attributes, sort_keys=True)
            })

            existing = result_check.fetchone()

            if existing:
                # Update existing pattern
                update_query = text("""
                    UPDATE silver_translation_patterns
                    SET last_requested = NOW(),
                        request_count = request_count + 1,
                        result_count = :result_count,
                        result_codes = :result_codes,
                        is_ambiguous = :is_ambiguous
                    WHERE pattern_id = :pattern_id
                """)

                session.execute(update_query, {
                    'pattern_id': existing.pattern_id,
                    'result_count': len(result.get('matches', [])),
                    'result_codes': json.dumps([m.get('target_code') for m in result.get('matches', [])]),
                    'is_ambiguous': len(result.get('matches', [])) > 1
                })
            else:
                # Create new pattern
                insert_query = text("""
                    INSERT INTO silver_translation_patterns
                    (source_taxonomy_id, target_taxonomy_id, source_code, source_attributes,
                     result_count, result_codes, is_ambiguous, resolution_method,
                     first_requested, last_requested, request_count)
                    VALUES (:source_taxonomy_id, :target_taxonomy_id, :source_code, :attributes,
                            :result_count, :result_codes, :is_ambiguous, :resolution_method,
                            NOW(), NOW(), 1)
                """)

                session.execute(insert_query, {
                    'source_taxonomy_id': source_taxonomy_id,
                    'target_taxonomy_id': target_taxonomy_id,
                    'source_code': source_code,
                    'attributes': json.dumps(attributes, sort_keys=True),
                    'result_count': len(result.get('matches', [])),
                    'result_codes': json.dumps([m.get('target_code') for m in result.get('matches', [])]),
                    'is_ambiguous': len(result.get('matches', [])) > 1,
                    'resolution_method': 'database_lookup'
                })

            session.commit()

        except Exception as e:
            logger.error(f"Error logging translation pattern: {str(e)}")


def get_taxonomy_id(session: Session, taxonomy_name: str) -> Optional[int]:
    """Get taxonomy ID by name"""

    if taxonomy_name.lower() == 'master':
        query = text("""
            SELECT taxonomy_id FROM silver_taxonomies
            WHERE type = 'master' LIMIT 1
        """)
        params = {}
    elif taxonomy_name.startswith('customer_'):
        customer_id = int(taxonomy_name.split('_')[1])
        query = text("""
            SELECT taxonomy_id FROM silver_taxonomies
            WHERE customer_id = :customer_id AND type = 'customer' LIMIT 1
        """)
        params = {'customer_id': customer_id}
    else:
        query = text("""
            SELECT taxonomy_id FROM silver_taxonomies
            WHERE name = :taxonomy_name LIMIT 1
        """)
        params = {'taxonomy_name': taxonomy_name}

    result = session.execute(query, params)
    match = result.fetchone()

    return match.taxonomy_id if match else None
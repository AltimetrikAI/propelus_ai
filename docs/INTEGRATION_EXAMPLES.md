# N/A Node Integration Examples

This document provides code examples for integrating N/A node support into existing Lambda functions.

## Overview

The N/A node implementation requires updates to three main Lambda functions:
1. **Ingestion Lambda** - Use NANodeHandler when creating nodes
2. **Mapping Lambda** - Handle N/A nodes in LLM prompts
3. **Translation Lambda** - Filter N/A nodes in responses

---

## 1. Ingestion Lambda Integration

### Import Required Classes

```typescript
import { Pool } from 'pg';
import { NANodeHandler, NODE_STATUS } from '@propelus/shared';
```

### Example: Creating Nodes with N/A Support

```typescript
/**
 * Process a taxonomy node row with automatic N/A gap filling
 */
async function processNodeRow(
  pool: Pool,
  nodeData: {
    taxonomy_id: number;
    node_type_id: number;
    value: string;
    profession: string;
    level: number;
    semantic_parent_id: number | null;
    semantic_parent_level: number | null;
    load_id: number;
    row_id: number;
  }
): Promise<number> {
  const naHandler = new NANodeHandler(pool);

  // Step 1: Get or create parent node (with N/A filling if needed)
  const parent_node_id = await naHandler.getOrCreateParentNode(
    nodeData.taxonomy_id,
    nodeData.level,
    nodeData.semantic_parent_id,
    nodeData.semantic_parent_level,
    nodeData.load_id,
    nodeData.row_id
  );

  // Step 2: Create the actual node
  const result = await pool.query<{ node_id: number }>(`
    INSERT INTO silver_taxonomies_nodes (
      node_type_id,
      taxonomy_id,
      parent_node_id,
      value,
      profession,
      level,
      status,
      created_at,
      last_updated_at,
      load_id,
      row_id
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, NOW(), NOW(), $8, $9)
    RETURNING node_id
  `, [
    nodeData.node_type_id,
    nodeData.taxonomy_id,
    parent_node_id,
    nodeData.value,
    nodeData.profession,
    nodeData.level,
    NODE_STATUS.ACTIVE,
    nodeData.load_id,
    nodeData.row_id
  ]);

  return result.rows[0].node_id;
}
```

### Example: Batch Processing with N/A Support

```typescript
/**
 * Process multiple nodes in a batch
 */
async function processBatchWithNASupport(
  pool: Pool,
  nodes: Array<{
    taxonomy_id: number;
    node_type_id: number;
    value: string;
    profession: string;
    level: number;
    parent_value?: string;  // Used to find semantic parent
    load_id: number;
    row_id: number;
  }>
): Promise<number[]> {
  const naHandler = new NANodeHandler(pool);
  const createdNodeIds: number[] = [];

  // Group nodes by level for efficient processing
  const nodesByLevel = nodes.reduce((acc, node) => {
    if (!acc[node.level]) acc[node.level] = [];
    acc[node.level].push(node);
    return acc;
  }, {} as Record<number, typeof nodes>);

  // Process level by level (ensures parents exist before children)
  const levels = Object.keys(nodesByLevel).map(Number).sort();

  for (const level of levels) {
    const levelNodes = nodesByLevel[level];

    for (const node of levelNodes) {
      // Find semantic parent if specified
      let semanticParentId: number | null = null;
      let semanticParentLevel: number | null = null;

      if (node.parent_value) {
        const parentResult = await pool.query<{ node_id: number; level: number }>(`
          SELECT node_id, level
          FROM silver_taxonomies_nodes
          WHERE taxonomy_id = $1
            AND value = $2
            AND status = 'active'
          LIMIT 1
        `, [node.taxonomy_id, node.parent_value]);

        if (parentResult.rows[0]) {
          semanticParentId = parentResult.rows[0].node_id;
          semanticParentLevel = parentResult.rows[0].level;
        }
      }

      // Create node with N/A support
      const nodeId = await processNodeRow(pool, {
        ...node,
        semantic_parent_id: semanticParentId,
        semantic_parent_level: semanticParentLevel
      });

      createdNodeIds.push(nodeId);
    }
  }

  return createdNodeIds;
}
```

---

## 2. Mapping Lambda Integration

### Import Required Classes

```typescript
import { Pool } from 'pg';
import { HierarchyQueries, NA_NODE_TYPE_ID } from '@propelus/shared';
import { BedrockRuntimeClient, InvokeModelCommand } from '@aws-sdk/client-bedrock-runtime';
```

### Example: LLM Matching with N/A Context

```typescript
/**
 * Find best match in master taxonomy using LLM with N/A awareness
 */
async function findMasterMatch(
  pool: Pool,
  bedrock: BedrockRuntimeClient,
  customerNodeId: number,
  masterTaxonomyId: number
): Promise<{ matchNodeId: number; confidence: number }> {
  const hierarchyQueries = new HierarchyQueries(pool);

  // Get full path (includes N/A for structural context)
  const fullPath = await hierarchyQueries.getFullPath(customerNodeId);

  // Format for LLM with explicit N/A marking
  const pathForLLM = hierarchyQueries.formatPathForLLM(fullPath);

  // Get target level (excluding N/A levels)
  const realPath = hierarchyQueries.filterNANodes(fullPath);
  const targetLevel = realPath[realPath.length - 1].level;

  // Get master candidates at same level (exclude N/A)
  const candidates = await pool.query(`
    SELECT node_id, value, profession
    FROM silver_taxonomies_nodes
    WHERE taxonomy_id = $1
      AND level = $2
      AND node_type_id != $3
      AND status = 'active'
    ORDER BY value
  `, [masterTaxonomyId, targetLevel, NA_NODE_TYPE_ID]);

  // Build LLM prompt with N/A instructions
  const prompt = `
You are matching a customer profession to the master taxonomy.

Customer Profession Path:
${pathForLLM}

IMPORTANT:
- "[SKIP]" marks N/A placeholder levels where hierarchy gaps exist
- Focus on the SEMANTIC MEANING of non-[SKIP] values
- Consider the LEVEL STRUCTURE indicated by "L1", "L2", etc.

Master Taxonomy Candidates:
${candidates.rows.map((c, i) => `${i + 1}. ${c.profession} (${c.value})`).join('\n')}

Return the best match with confidence (0-100).
Format: {"candidate": <number>, "confidence": <score>, "reasoning": "<explanation>"}
`;

  // Call Bedrock
  const response = await bedrock.send(new InvokeModelCommand({
    modelId: process.env.BEDROCK_MODEL_ID,
    contentType: 'application/json',
    accept: 'application/json',
    body: JSON.stringify({
      anthropic_version: 'bedrock-2023-05-31',
      max_tokens: 1000,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.1
    })
  }));

  const responseBody = JSON.parse(new TextDecoder().decode(response.body));
  const result = JSON.parse(responseBody.content[0].text);

  return {
    matchNodeId: candidates.rows[result.candidate - 1].node_id,
    confidence: result.confidence
  };
}
```

### Example: Query Master Nodes (Excluding N/A)

```typescript
/**
 * Get master taxonomy nodes at specific level, excluding N/A placeholders
 */
async function getMasterNodesAtLevel(
  pool: Pool,
  masterTaxonomyId: number,
  level: number
): Promise<Array<{ node_id: number; value: string; profession: string }>> {
  const result = await pool.query(`
    SELECT node_id, value, profession
    FROM silver_taxonomies_nodes
    WHERE taxonomy_id = $1
      AND level = $2
      AND node_type_id != $3
      AND status = 'active'
    ORDER BY value
  `, [masterTaxonomyId, level, NA_NODE_TYPE_ID]);

  return result.rows;
}
```

---

## 3. Translation Lambda Integration

### Import Required Classes

```typescript
import { Pool } from 'pg';
import { HierarchyQueries, NA_NODE_TYPE_ID } from '@propelus/shared';
```

### Example: Translation with Display Paths

```typescript
/**
 * Translate profession code between taxonomies with N/A-filtered display
 */
async function translateProfession(
  pool: Pool,
  request: {
    source_taxonomy: string;
    source_code: string;
    target_taxonomy: string;
  }
): Promise<{
  source_path: string;
  target_path: string;
  matches: Array<{ code: string; path: string }>;
}> {
  const hierarchyQueries = new HierarchyQueries(pool);

  // Find source node (exclude N/A in search)
  const sourceNode = await pool.query(`
    SELECT n.node_id
    FROM silver_taxonomies_nodes n
    INNER JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
    WHERE t.name = $1
      AND n.value = $2
      AND n.node_type_id != $3
      AND n.status = 'active'
    LIMIT 1
  `, [request.source_taxonomy, request.source_code, NA_NODE_TYPE_ID]);

  if (sourceNode.rows.length === 0) {
    throw new Error('Source profession not found');
  }

  const sourceNodeId = sourceNode.rows[0].node_id;

  // Get display path (N/A filtered automatically)
  const sourcePath = await hierarchyQueries.getDisplayPath(sourceNodeId);

  // Get mapping to master
  const mapping = await pool.query(`
    SELECT master_node_id
    FROM gold_mapping_taxonomies
    WHERE child_node_id = $1
    LIMIT 1
  `, [sourceNodeId]);

  if (mapping.rows.length === 0) {
    throw new Error('No mapping found');
  }

  const masterNodeId = mapping.rows[0].master_node_id;

  // Find target matches (exclude N/A)
  const targets = await pool.query(`
    SELECT n.node_id, n.value
    FROM gold_mapping_taxonomies m
    INNER JOIN silver_taxonomies_nodes n ON m.child_node_id = n.node_id
    INNER JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
    WHERE m.master_node_id = $1
      AND t.name = $2
      AND n.node_type_id != $3
      AND n.status = 'active'
  `, [masterNodeId, request.target_taxonomy, NA_NODE_TYPE_ID]);

  // Get display paths for all targets
  const matches = await Promise.all(
    targets.rows.map(async (target) => ({
      code: target.value,
      path: await hierarchyQueries.getDisplayPath(target.node_id)
    }))
  );

  return {
    source_path: sourcePath,
    target_path: await hierarchyQueries.getDisplayPath(masterNodeId),
    matches
  };
}
```

### Example: Finding Source Node (N/A Filtered)

```typescript
/**
 * Find source node by code, excluding N/A placeholders
 */
async function findSourceNode(
  pool: Pool,
  taxonomyName: string,
  code: string
): Promise<number | null> {
  const result = await pool.query<{ node_id: number }>(`
    SELECT n.node_id
    FROM silver_taxonomies_nodes n
    INNER JOIN silver_taxonomies t ON n.taxonomy_id = t.taxonomy_id
    WHERE t.name = $1
      AND n.value = $2
      AND n.node_type_id != $3
      AND n.status = 'active'
    LIMIT 1
  `, [taxonomyName, code, NA_NODE_TYPE_ID]);

  return result.rows[0]?.node_id || null;
}
```

---

## Common Patterns

### Pattern 1: Always Filter N/A in Display Queries

```typescript
// ✅ GOOD: Exclude N/A nodes
const nodes = await pool.query(`
  SELECT * FROM silver_taxonomies_nodes
  WHERE parent_node_id = $1
    AND node_type_id != $2  -- Exclude N/A
    AND status = 'active'
`, [parentId, NA_NODE_TYPE_ID]);
```

### Pattern 2: Include N/A for LLM Context

```typescript
// ✅ GOOD: Include N/A for structural understanding
const fullPath = await hierarchyQueries.getFullPath(nodeId);
const llmPrompt = hierarchyQueries.formatPathForLLM(fullPath);
// Result: "L1:Healthcare → [SKIP]:N/A → L3:Nurse"
```

### Pattern 3: Use Helper Functions

```typescript
// ✅ GOOD: Use HierarchyQueries helpers
const displayPath = await hierarchyQueries.getDisplayPath(nodeId);
// Result: "Healthcare → Nurse" (N/A automatically filtered)
```

---

## Testing Your Integration

After integrating N/A support, test with:

```bash
# Run N/A node tests
npm run test:na-nodes

# Check for N/A pollution in results
SELECT * FROM your_result_table WHERE value LIKE '%N/A%';

# Verify N/A nodes are reused (shouldn't see duplicates)
SELECT taxonomy_id, level, parent_node_id, COUNT(*)
FROM silver_taxonomies_nodes
WHERE node_type_id = -1
GROUP BY taxonomy_id, level, parent_node_id
HAVING COUNT(*) > 1;
```

---

## Key Reminders

1. **Never create N/A nodes manually** - Always use `NANodeHandler`
2. **Filter N/A in display queries** - Use `node_type_id != -1` or helper functions
3. **Include N/A in LLM prompts** - Provides structural context
4. **Use helper functions** - `HierarchyQueries` handles complexity for you
5. **Check N/A reuse** - `findOrCreateNANode()` prevents duplicates

---

## Additional Resources

- **SQL Functions**: See `scripts/migrations/002-create-hierarchy-helper-functions.sql`
- **Class Documentation**: See `shared/utils/na-node-handler.ts` and `shared/database/queries/hierarchy-queries.ts`
- **Migration Guide**: See `scripts/migrations/README.md`

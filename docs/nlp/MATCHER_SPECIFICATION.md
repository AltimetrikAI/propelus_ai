# NLP Qualifier Matcher Specification

## Overview

Specification for implementing the NLP Qualifier Matcher in Mapping Rules Lambda (Lambda #3).

## Matcher Types

### 1. Strong Occupation Matcher

**Pattern**: Multi-word detailed occupation (anywhere in text)

**Logic**:
```typescript
// Match if detailed occupation phrase appears in text
// Example: "Advanced Psychiatric Nurse" in "I am an Advanced Psychiatric Nurse"
confidence: 95%
```

**Extraction Criteria**:
- Detailed Occupation level nodes
- 2+ words in value
- From master taxonomy hierarchy

**Example Matches**:
- "Clinical Social Worker"
- "Licensed Practical Nurse"
- "Registered Nurse Practitioner"

---

### 2. Qualified Suffix Matcher

**Pattern**: QUALIFIER + HEAD

**Logic**:
```typescript
// Requires qualifier BEFORE head term
// Example: "Clinical" + "Social Worker"
if (hasQualifierPrefix && endsWithHead) {
  confidence: 90%
}
```

**Qualified Heads (Generic Terms)**:
- nurse
- therapist
- counselor
- specialist
- coordinator
- manager
- worker
- navigator
- assistant
- associate

**Qualifiers**:
- Industry names: "Healthcare", "Medical", "Behavioral"
- Minor groups: "Social Services", "Mental Health"
- Extracted prefixes: "Clinical", "Licensed", "Registered"

**Example Matches**:
- "Clinical" + "Nurse" → Match
- "Licensed" + "Social Worker" → Match
- "Behavioral" + "Therapist" → Match
- "Nurse" (alone) → No match (needs qualifier)

---

### 3. Qualified Prefix Matcher

**Pattern**: HEAD + QUALIFIER

**Logic**:
```typescript
// Requires qualifier AFTER head term
// Example: "Nurse" + "Practitioner"
if (startsWithHead && hasQualifierSuffix) {
  confidence: 90%
}
```

**Example Matches**:
- "Nurse" + "Practitioner" → Match
- "Social" + "Worker" → Match
- "Case" + "Manager" → Match

---

## Vocabulary Extraction

### From Taxonomy Hierarchy

**Query Pattern**:
```sql
SELECT
  n.value,
  n.level,
  nt.name as node_type
FROM silver_taxonomies_nodes n
JOIN silver_taxonomies_nodes_types nt ON n.node_type_id = nt.node_type_id
WHERE n.taxonomy_id = $1  -- Master taxonomy
  AND n.status = 'active'
  AND n.node_type_id != -1  -- Exclude N/A
ORDER BY n.level ASC;
```

### Vocabulary Sets

**Strong Heads**:
```typescript
// Multi-word detailed occupations (level 4-5)
SELECT value FROM silver_taxonomies_nodes
WHERE level >= 4
  AND array_length(string_to_array(value, ' '), 1) >= 2;
```

**Qualified Heads**:
```typescript
// Generic terms found in taxonomy
SELECT DISTINCT value FROM silver_taxonomies_nodes
WHERE value ~* 'nurse|therapist|counselor|specialist|worker';
```

**Qualifiers**:
```typescript
// Industry, Minor Group, and extracted prefixes
- Industry level (level 0-1)
- Minor Group level (level 2-3)
- Prefixes before qualified heads
```

---

## Text Normalization

### Preprocessing Steps

```typescript
function normalize(text: string): string {
  // 1. Replace separators with spaces
  text = text.replace(/[-\/]/g, ' ');

  // 2. Remove punctuation
  text = text.replace(/[()",;:.[\]{}!?\u2013\u2014]/g, ' ');

  // 3. Collapse whitespace
  text = text.replace(/\s+/g, ' ').trim();

  // 4. Lowercase
  return text.toLowerCase();
}
```

---

## Tokenization

### Using Compromise (JavaScript NLP)

```typescript
import nlp from 'compromise';

function tokenize(text: string): string[] {
  const doc = nlp(text);
  return doc.terms().out('array');
}
```

---

## Pattern Matching Algorithm

### Pseudocode

```typescript
function matchNLP(customerValue: string, masterNodes: Node[]): MatchResult {
  const normalized = normalize(customerValue);
  const tokens = tokenize(normalized);

  // 1. Try strong occupation match (highest confidence)
  for (const head of strongHeads) {
    if (containsPhrase(tokens, head)) {
      const master = findMasterByValue(masterNodes, head);
      if (master) {
        return { matched: true, confidence: 95, master };
      }
    }
  }

  // 2. Try qualified suffix (QUALIFIER + HEAD)
  for (const head of qualifiedHeads) {
    const headIndex = findPhrase(tokens, head);
    if (headIndex > 0) {  // Has prefix
      const prefix = tokens.slice(0, headIndex).join(' ');
      if (hasQualifier(prefix, qualifiers)) {
        const master = findMasterByPattern(masterNodes, prefix, head);
        if (master) {
          return { matched: true, confidence: 90, master };
        }
      }
    }
  }

  // 3. Try qualified prefix (HEAD + QUALIFIER)
  for (const head of qualifiedHeads) {
    const headIndex = findPhrase(tokens, head);
    const headLength = head.split(' ').length;
    if (headIndex >= 0 && headIndex + headLength < tokens.length) {  // Has suffix
      const suffix = tokens.slice(headIndex + headLength).join(' ');
      if (hasQualifier(suffix, qualifiers)) {
        const master = findMasterByPattern(masterNodes, head, suffix);
        if (master) {
          return { matched: true, confidence: 90, master };
        }
      }
    }
  }

  return { matched: false, confidence: 0 };
}
```

---

## Confidence Scoring

| Pattern Type | Confidence | Reason |
|--------------|-----------|---------|
| Strong Occupation | 95% | Multi-word detailed occupation |
| Qualified Suffix | 90% | Context-aware with prefix qualifier |
| Qualified Prefix | 90% | Context-aware with suffix qualifier |
| No Match | 0% | Falls through to next matcher |

---

## Performance Targets

- **Vocabulary extraction**: < 500ms (cached per taxonomy)
- **Pattern matching**: < 100ms per customer node
- **Memory usage**: < 50MB for vocabulary sets

---

## Testing Strategy

### Unit Tests

```typescript
describe('NLPQualifierMatcher', () => {
  it('matches strong occupation', () => {
    expect(match('Clinical Social Worker')).toEqual({
      matched: true,
      confidence: 95
    });
  });

  it('matches qualified suffix', () => {
    expect(match('Licensed Nurse')).toEqual({
      matched: true,
      confidence: 90
    });
  });

  it('rejects unqualified head', () => {
    expect(match('Nurse')).toEqual({
      matched: false,
      confidence: 0
    });
  });
});
```

---

## Implementation Files

1. `vocabulary-extractor.ts` - Extract from taxonomy
2. `nlp-qualifier-matcher.ts` - Main matcher logic
3. `text-normalizer.ts` - Preprocessing utilities
4. `pattern-engine.ts` - Token pattern matching

---

## Integration Point

```typescript
// mapping-engine.ts
const result =
  exactMatcher.match(...) ||
  nlpMatcher.match(...) ||      // ← NEW
  fuzzyMatcher.match(...) ||
  aiMatcher.match(...);
```

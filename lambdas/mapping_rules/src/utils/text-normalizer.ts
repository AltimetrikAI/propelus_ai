/**
 * Text Normalization Utilities
 * Preprocessing and tokenization for NLP matching
 */

import nlp from 'compromise';

/**
 * Normalize text for matching
 * - Replace separators with spaces
 * - Remove punctuation
 * - Collapse whitespace
 * - Lowercase
 */
export function normalize(text: string): string {
  if (!text) return '';

  // Replace separators with spaces
  let normalized = text.replace(/[-\/]/g, ' ');

  // Remove punctuation
  normalized = normalized.replace(/[()",;:.[\]{}!?\u2013\u2014]/g, ' ');

  // Collapse whitespace
  normalized = normalized.replace(/\s+/g, ' ').trim();

  // Lowercase
  return normalized.toLowerCase();
}

/**
 * Tokenize text using compromise NLP
 */
export function tokenize(text: string): string[] {
  const normalized = normalize(text);
  if (!normalized) return [];

  const doc = nlp(normalized);
  return doc.terms().out('array') as string[];
}

/**
 * Check if a phrase exists in token array
 */
export function containsPhrase(tokens: string[], phrase: string): boolean {
  const phraseTokens = phrase.toLowerCase().split(' ');
  const phraseLen = phraseTokens.length;

  for (let i = 0; i <= tokens.length - phraseLen; i++) {
    let match = true;
    for (let j = 0; j < phraseLen; j++) {
      if (tokens[i + j] !== phraseTokens[j]) {
        match = false;
        break;
      }
    }
    if (match) return true;
  }

  return false;
}

/**
 * Find phrase index in token array
 * Returns starting index or -1 if not found
 */
export function findPhraseIndex(tokens: string[], phrase: string): number {
  const phraseTokens = phrase.toLowerCase().split(' ');
  const phraseLen = phraseTokens.length;

  for (let i = 0; i <= tokens.length - phraseLen; i++) {
    let match = true;
    for (let j = 0; j < phraseLen; j++) {
      if (tokens[i + j] !== phraseTokens[j]) {
        match = false;
        break;
      }
    }
    if (match) return i;
  }

  return -1;
}

/**
 * Check if text contains any of the qualifiers
 */
export function hasQualifier(text: string, qualifiers: Set<string>): boolean {
  const normalized = normalize(text);
  for (const qualifier of qualifiers) {
    if (normalized.includes(qualifier.toLowerCase())) {
      return true;
    }
  }
  return false;
}

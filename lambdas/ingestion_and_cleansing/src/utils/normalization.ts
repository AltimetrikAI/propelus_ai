/**
 * String Normalization Utilities (Algorithm §0)
 *
 * Critical for case-insensitive uniqueness and data quality
 */

/**
 * Normalize string: trim and collapse whitespace
 * §0: normalize(s) = trim(s) with collapsed whitespace
 */
export function normalize(s: any): string {
  if (s === null || s === undefined) return '';
  return String(s).trim().replace(/\s+/g, ' ');
}

/**
 * Lowercase string for case-insensitive comparison
 * §0: lower(s) = s.toLowerCase()
 */
export function lower(s: string): string {
  return s.toLocaleLowerCase();
}

/**
 * Safe string access with normalization
 */
export function safeString(value: any, defaultValue: string = ''): string {
  if (value === null || value === undefined) return defaultValue;
  return normalize(value);
}

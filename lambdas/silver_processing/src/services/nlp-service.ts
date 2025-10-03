/**
 * NLP Service
 *
 * Natural Language Processing for extracting and normalizing profession information.
 * Uses libraries like Natural and Compromise for text analysis.
 */

import natural from 'natural';
import compromise from 'compromise';
import { logger } from '../../../../shared/utils/logger';

export interface ProfessionInfo {
  name: string;
  attributes: Record<string, any>;
  confidence: number;
}

export class NLPService {
  private tokenizer: natural.WordTokenizer;
  private stemmer: typeof natural.PorterStemmer;

  constructor() {
    this.tokenizer = new natural.WordTokenizer();
    this.stemmer = natural.PorterStemmer;
  }

  /**
   * Extract profession information from raw data
   */
  extractProfessionInfo(data: Record<string, any>): ProfessionInfo {
    logger.info('Extracting profession info', { data });

    const professionName = this.extractProfessionName(data);
    const attributes = this.extractAttributes(data);
    const confidence = this.calculateConfidence(data);

    return {
      name: this.normalizeProfessionName(professionName),
      attributes,
      confidence,
    };
  }

  /**
   * Extract profession name from various possible field names
   */
  private extractProfessionName(data: Record<string, any>): string {
    const possibleFields = [
      'profession',
      'profession_name',
      'professionName',
      'occupation',
      'job_title',
      'title',
      'profession_description',
      'description',
      'license_type',
      'licenseType',
    ];

    for (const field of possibleFields) {
      if (data[field]) {
        return String(data[field]);
      }
    }

    // If no specific field found, try to extract from combined fields
    const combinedText = Object.values(data)
      .filter((v) => typeof v === 'string')
      .join(' ');

    return this.extractProfessionFromText(combinedText);
  }

  /**
   * Use NLP to extract profession from text
   */
  private extractProfessionFromText(text: string): string {
    const doc = compromise(text);

    // Try to find job titles
    const jobs = doc.match('#Job').out('array');
    if (jobs.length > 0) {
      return jobs[0];
    }

    // Try to find nouns that might be professions
    const nouns = doc.nouns().out('array');
    if (nouns.length > 0) {
      return nouns[0];
    }

    return text.split(' ')[0]; // Fallback to first word
  }

  /**
   * Normalize profession name
   */
  private normalizeProfessionName(name: string): string {
    return name
      .trim()
      .replace(/\s+/g, ' ') // Normalize whitespace
      .replace(/[^\w\s-]/g, '') // Remove special chars except hyphen
      .toLowerCase()
      .split(' ')
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  }

  /**
   * Extract attributes from data
   */
  private extractAttributes(data: Record<string, any>): Record<string, any> {
    const attributes: Record<string, any> = {};

    const attributeFields = [
      'state',
      'state_code',
      'license_number',
      'licenseNumber',
      'issuing_authority',
      'issuingAuthority',
      'expiration_date',
      'expirationDate',
      'status',
      'specialty',
      'certification',
      'level',
      'category',
    ];

    for (const field of attributeFields) {
      if (data[field] !== undefined && data[field] !== null) {
        attributes[field] = data[field];
      }
    }

    // Extract state code if present
    if (data.state) {
      attributes.state_code = this.extractStateCode(String(data.state));
    }

    return attributes;
  }

  /**
   * Extract state code from state name or abbreviation
   */
  private extractStateCode(state: string): string {
    const stateMap: Record<string, string> = {
      alabama: 'AL',
      alaska: 'AK',
      arizona: 'AZ',
      arkansas: 'AR',
      california: 'CA',
      colorado: 'CO',
      connecticut: 'CT',
      delaware: 'DE',
      florida: 'FL',
      georgia: 'GA',
      hawaii: 'HI',
      idaho: 'ID',
      illinois: 'IL',
      indiana: 'IN',
      iowa: 'IA',
      kansas: 'KS',
      kentucky: 'KY',
      louisiana: 'LA',
      maine: 'ME',
      maryland: 'MD',
      massachusetts: 'MA',
      michigan: 'MI',
      minnesota: 'MN',
      mississippi: 'MS',
      missouri: 'MO',
      montana: 'MT',
      nebraska: 'NE',
      nevada: 'NV',
      'new hampshire': 'NH',
      'new jersey': 'NJ',
      'new mexico': 'NM',
      'new york': 'NY',
      'north carolina': 'NC',
      'north dakota': 'ND',
      ohio: 'OH',
      oklahoma: 'OK',
      oregon: 'OR',
      pennsylvania: 'PA',
      'rhode island': 'RI',
      'south carolina': 'SC',
      'south dakota': 'SD',
      tennessee: 'TN',
      texas: 'TX',
      utah: 'UT',
      vermont: 'VT',
      virginia: 'VA',
      washington: 'WA',
      'west virginia': 'WV',
      wisconsin: 'WI',
      wyoming: 'WY',
    };

    const normalized = state.toLowerCase().trim();

    // Check if it's already a 2-letter code
    if (/^[A-Z]{2}$/i.test(state.trim())) {
      return state.toUpperCase();
    }

    // Look up state name
    return stateMap[normalized] || state.toUpperCase();
  }

  /**
   * Calculate confidence score for extraction
   */
  private calculateConfidence(data: Record<string, any>): number {
    let score = 0.5; // Base score

    // Increase confidence if specific fields are present
    if (data.profession || data.profession_name) score += 0.2;
    if (data.state || data.state_code) score += 0.1;
    if (data.license_number || data.licenseNumber) score += 0.1;
    if (data.issuing_authority) score += 0.1;

    return Math.min(score, 1.0);
  }

  /**
   * Tokenize text for analysis
   */
  tokenize(text: string): string[] {
    return this.tokenizer.tokenize(text) || [];
  }

  /**
   * Stem word to its root form
   */
  stem(word: string): string {
    return this.stemmer.stem(word);
  }
}

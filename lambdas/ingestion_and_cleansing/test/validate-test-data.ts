/**
 * Test Data Validator
 *
 * Validates generated test data against Lambda event schemas
 * and Excel layout requirements before testing.
 */

import * as XLSX from 'xlsx';
import * as fs from 'fs';

// ============================================
// Type Definitions
// ============================================

type TaxonomyType = 'master' | 'customer';

interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

// ============================================
// Excel Layout Validators
// ============================================

export function validateMasterExcelLayout(
  headers: string[]
): ValidationResult {
  const result: ValidationResult = {
    valid: true,
    errors: [],
    warnings: []
  };

  // Extract node and attribute columns
  const nodeColumns = headers.filter(h => /\(node\)\s*$/i.test(h));
  const attributeColumns = headers.filter(h => /\(attribute\)\s*$/i.test(h));

  // Must have at least one node column
  if (nodeColumns.length === 0) {
    result.valid = false;
    result.errors.push('Master taxonomy must have at least one column ending with "(node)"');
  }

  // Check for common node types
  const nodeTypes = nodeColumns.map(h =>
    h.replace(/\(node\)\s*$/i, '').trim().toLowerCase()
  );

  const expectedNodes = ['industry', 'group', 'occupation'];
  const missingNodes = expectedNodes.filter(n => !nodeTypes.includes(n));

  if (missingNodes.length > 0) {
    result.warnings.push(
      `Recommended node types missing: ${missingNodes.join(', ')}`
    );
  }

  // Check for common attributes
  if (attributeColumns.length > 0) {
    const attrTypes = attributeColumns.map(h =>
      h.replace(/\(attribute\)\s*$/i, '').trim().toLowerCase()
    );

    const recommendedAttrs = ['level', 'status'];
    const missingAttrs = recommendedAttrs.filter(a => !attrTypes.includes(a));

    if (missingAttrs.length > 0) {
      result.warnings.push(
        `Recommended attribute types missing: ${missingAttrs.join(', ')}`
      );
    }
  }

  return result;
}

export function validateCustomerExcelLayout(
  headers: string[]
): ValidationResult {
  const result: ValidationResult = {
    valid: true,
    errors: [],
    warnings: []
  };

  // Must have exactly one profession column
  const professionColumns = headers.filter(h =>
    /\(profession\)\s*$/i.test(h)
  );

  if (professionColumns.length === 0) {
    result.valid = false;
    result.errors.push(
      'Customer taxonomy must have exactly one column ending with "(profession)"'
    );
  } else if (professionColumns.length > 1) {
    result.valid = false;
    result.errors.push(
      `Customer taxonomy must have exactly one "(profession)" column, found ${professionColumns.length}`
    );
  }

  // Check for common attribute columns
  const otherColumns = headers.filter(
    h => !/\(profession\)\s*$/i.test(h)
  );

  if (otherColumns.length === 0) {
    result.warnings.push(
      'No attribute columns found. Consider adding State, Department, etc.'
    );
  }

  return result;
}

// ============================================
// Excel File Validator
// ============================================

export function validateExcelFile(
  filePath: string,
  taxonomyType: TaxonomyType
): ValidationResult {
  const result: ValidationResult = {
    valid: true,
    errors: [],
    warnings: []
  };

  // Check file exists
  if (!fs.existsSync(filePath)) {
    result.valid = false;
    result.errors.push(`File not found: ${filePath}`);
    return result;
  }

  try {
    // Read Excel file
    const workbook = XLSX.readFile(filePath);

    // Check for at least one sheet
    if (workbook.SheetNames.length === 0) {
      result.valid = false;
      result.errors.push('Excel file has no sheets');
      return result;
    }

    // Read first sheet
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];

    // Convert to array
    const data = XLSX.utils.sheet_to_json(worksheet, { header: 1 }) as any[][];

    // Check for header row
    if (data.length === 0) {
      result.valid = false;
      result.errors.push('Excel file is empty');
      return result;
    }

    // Get headers
    const headers = data[0] as string[];

    // Validate headers based on taxonomy type
    const layoutResult =
      taxonomyType === 'master'
        ? validateMasterExcelLayout(headers)
        : validateCustomerExcelLayout(headers);

    result.valid = result.valid && layoutResult.valid;
    result.errors.push(...layoutResult.errors);
    result.warnings.push(...layoutResult.warnings);

    // Check for data rows
    if (data.length === 1) {
      result.warnings.push('Excel file has no data rows (only headers)');
    }

    // Check for empty cells in first 5 rows
    const sampleRows = data.slice(1, 6);
    let hasEmptyCells = false;

    for (let i = 0; i < sampleRows.length; i++) {
      const row = sampleRows[i];
      for (let j = 0; j < headers.length; j++) {
        if (!row[j] || String(row[j]).trim() === '') {
          hasEmptyCells = true;
          break;
        }
      }
      if (hasEmptyCells) break;
    }

    if (hasEmptyCells) {
      result.warnings.push(
        'Some cells in sample rows are empty. This may cause row processing errors.'
      );
    }

  } catch (err) {
    result.valid = false;
    result.errors.push(`Failed to read Excel file: ${err}`);
  }

  return result;
}

// ============================================
// API Event Validator
// ============================================

export function validateApiEvent(event: any): ValidationResult {
  const result: ValidationResult = {
    valid: true,
    errors: [],
    warnings: []
  };

  // Check source
  if (event.source !== 'api') {
    result.valid = false;
    result.errors.push(`Invalid source: ${event.source}. Expected "api"`);
  }

  // Check taxonomyType
  if (!['master', 'customer'].includes(event.taxonomyType)) {
    result.valid = false;
    result.errors.push(
      `Invalid taxonomyType: ${event.taxonomyType}. Must be "master" or "customer"`
    );
  }

  // Check payload
  if (!event.payload) {
    result.valid = false;
    result.errors.push('Missing payload');
    return result;
  }

  const { payload } = event;

  // Check required fields
  if (!payload.customer_id) {
    result.valid = false;
    result.errors.push('Missing payload.customer_id');
  }

  if (!payload.taxonomy_id) {
    result.valid = false;
    result.errors.push('Missing payload.taxonomy_id');
  }

  if (!payload.taxonomy_name) {
    result.warnings.push('Missing payload.taxonomy_name (optional)');
  }

  // Check layout
  if (!payload.layout) {
    result.valid = false;
    result.errors.push('Missing payload.layout');
    return result;
  }

  // Validate layout structure
  if (event.taxonomyType === 'master') {
    if (!payload.layout.Nodes || !Array.isArray(payload.layout.Nodes)) {
      result.valid = false;
      result.errors.push('Master layout must have "Nodes" array');
    } else if (payload.layout.Nodes.length === 0) {
      result.valid = false;
      result.errors.push('Master layout "Nodes" array cannot be empty');
    }

    if (
      payload.layout.Attributes &&
      !Array.isArray(payload.layout.Attributes)
    ) {
      result.valid = false;
      result.errors.push('Master layout "Attributes" must be an array');
    }
  } else {
    if (!payload.layout['Proffesion column']) {
      result.valid = false;
      result.errors.push(
        'Customer layout must have "Proffesion column" object'
      );
    } else if (!payload.layout['Proffesion column'].Profession) {
      result.valid = false;
      result.errors.push(
        'Customer layout "Proffesion column" must have "Profession" field'
      );
    }
  }

  // Check rows
  if (!payload.rows || !Array.isArray(payload.rows)) {
    result.valid = false;
    result.errors.push('Missing or invalid payload.rows');
  } else if (payload.rows.length === 0) {
    result.warnings.push('payload.rows is empty');
  }

  return result;
}

// ============================================
// S3 Event Validator
// ============================================

export function validateS3Event(event: any): ValidationResult {
  const result: ValidationResult = {
    valid: true,
    errors: [],
    warnings: []
  };

  // Check source
  if (event.source !== 's3') {
    result.valid = false;
    result.errors.push(`Invalid source: ${event.source}. Expected "s3"`);
  }

  // Check taxonomyType
  if (!['master', 'customer'].includes(event.taxonomyType)) {
    result.valid = false;
    result.errors.push(
      `Invalid taxonomyType: ${event.taxonomyType}. Must be "master" or "customer"`
    );
  }

  // Check bucket
  if (!event.bucket) {
    result.valid = false;
    result.errors.push('Missing bucket');
  }

  // Check key
  if (!event.key) {
    result.valid = false;
    result.errors.push('Missing key');
  } else {
    // Validate filename format
    const keyPattern = /customer-([^_]+)__taxonomy-([^_]+)__(.+)\.(xlsx|xls)$/i;
    if (!keyPattern.test(event.key)) {
      result.valid = false;
      result.errors.push(
        'Key must match format: customer-<id>__taxonomy-<id>__<name>.(xlsx|xls)'
      );
    }
  }

  return result;
}

// ============================================
// Batch Validator
// ============================================

export function validateAllTestData(testDataDir: string): void {
  console.log('🔍 Validating test data...\n');

  let totalErrors = 0;
  let totalWarnings = 0;

  // Validate Excel files
  const excelFiles = [
    { path: `${testDataDir}/master-social-work.xlsx`, type: 'master' as TaxonomyType },
    { path: `${testDataDir}/master-nurse-practitioners.xlsx`, type: 'master' as TaxonomyType },
    { path: `${testDataDir}/customer-hospital-a.xlsx`, type: 'customer' as TaxonomyType }
  ];

  for (const file of excelFiles) {
    console.log(`📄 ${file.path}`);
    const result = validateExcelFile(file.path, file.type);

    if (result.valid) {
      console.log('   ✅ Valid');
    } else {
      console.log('   ❌ Invalid');
    }

    if (result.errors.length > 0) {
      totalErrors += result.errors.length;
      result.errors.forEach(err => console.log(`   ❌ ERROR: ${err}`));
    }

    if (result.warnings.length > 0) {
      totalWarnings += result.warnings.length;
      result.warnings.forEach(warn => console.log(`   ⚠️  WARNING: ${warn}`));
    }

    console.log('');
  }

  // Validate API events
  const apiEventsPath = `${testDataDir}/api-events.json`;
  if (fs.existsSync(apiEventsPath)) {
    const apiEvents = JSON.parse(fs.readFileSync(apiEventsPath, 'utf-8'));

    for (const [name, event] of Object.entries(apiEvents)) {
      console.log(`🔌 API Event: ${name}`);
      const result = validateApiEvent(event);

      if (result.valid) {
        console.log('   ✅ Valid');
      } else {
        console.log('   ❌ Invalid');
      }

      if (result.errors.length > 0) {
        totalErrors += result.errors.length;
        result.errors.forEach(err => console.log(`   ❌ ERROR: ${err}`));
      }

      if (result.warnings.length > 0) {
        totalWarnings += result.warnings.length;
        result.warnings.forEach(warn => console.log(`   ⚠️  WARNING: ${warn}`));
      }

      console.log('');
    }
  }

  // Validate S3 events
  const s3EventsPath = `${testDataDir}/s3-events.json`;
  if (fs.existsSync(s3EventsPath)) {
    const s3Events = JSON.parse(fs.readFileSync(s3EventsPath, 'utf-8'));

    for (const [name, event] of Object.entries(s3Events)) {
      console.log(`☁️  S3 Event: ${name}`);
      const result = validateS3Event(event);

      if (result.valid) {
        console.log('   ✅ Valid');
      } else {
        console.log('   ❌ Invalid');
      }

      if (result.errors.length > 0) {
        totalErrors += result.errors.length;
        result.errors.forEach(err => console.log(`   ❌ ERROR: ${err}`));
      }

      if (result.warnings.length > 0) {
        totalWarnings += result.warnings.length;
        result.warnings.forEach(warn => console.log(`   ⚠️  WARNING: ${warn}`));
      }

      console.log('');
    }
  }

  // Summary
  console.log('━'.repeat(50));
  console.log('📊 Validation Summary');
  console.log('━'.repeat(50));

  if (totalErrors === 0 && totalWarnings === 0) {
    console.log('✅ All test data is valid with no warnings!');
  } else {
    if (totalErrors > 0) {
      console.log(`❌ Total Errors: ${totalErrors}`);
    }
    if (totalWarnings > 0) {
      console.log(`⚠️  Total Warnings: ${totalWarnings}`);
    }

    if (totalErrors > 0) {
      console.log('\n❌ Fix errors before using test data.');
      process.exit(1);
    }
  }
}

// ============================================
// CLI Usage
// ============================================

if (require.main === module) {
  const testDataDir = process.argv[2] || './test-data';
  validateAllTestData(testDataDir);
}

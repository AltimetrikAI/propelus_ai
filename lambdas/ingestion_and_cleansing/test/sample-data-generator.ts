/**
 * Test Data Generator for Ingestion & Cleansing Lambda
 *
 * Generates sample Excel files and API payloads for testing.
 * Based on Kristen's sample taxonomies:
 * - Social Work (223 professions - complex hierarchy)
 * - Nurse Practitioners (simpler structure)
 */

import * as XLSX from 'xlsx';
import * as fs from 'fs';
import * as path from 'path';

// ============================================
// SAMPLE 1: Master Taxonomy - Social Work
// ============================================

const socialWorkMasterData = [
  // Header row (with markers)
  ['Industry (node)', 'Group (node)', 'Occupation (node)', 'Level (attribute)', 'Status (attribute)'],

  // Data rows - representative sample of 223 professions
  ['Healthcare', 'Social Work', 'Licensed Clinical Social Worker (LCSW)', 'Licensed', 'Active'],
  ['Healthcare', 'Social Work', 'Licensed Clinical Social Worker (LCSW)', 'Licensed', 'Temporary'],
  ['Healthcare', 'Social Work', 'Licensed Social Worker (LSW)', 'Licensed', 'Active'],
  ['Healthcare', 'Social Work', 'Licensed Social Worker (LSW)', 'Licensed', 'Provisional'],
  ['Healthcare', 'Social Work', 'Clinical Social Worker (CSW)', 'Certified', 'Active'],
  ['Healthcare', 'Social Work', 'Master Social Worker (MSW)', 'Registered', 'Active'],
  ['Healthcare', 'Social Work', 'Bachelor Social Worker (BSW)', 'Registered', 'Active'],
  ['Healthcare', 'Social Work', 'Social Work Supervisor', 'Supervisor', 'Active'],
  ['Healthcare', 'Social Work', 'Social Work Intern', 'Provisional', 'Temporary'],
  ['Healthcare', 'Social Work', 'Clinical Social Work Supervisor', 'Supervisor', 'Active'],

  // Additional variations
  ['Healthcare', 'Social Work', 'Licensed Independent Social Worker (LISW)', 'Licensed', 'Active'],
  ['Healthcare', 'Social Work', 'Advanced Practice Clinical Social Worker', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Social Work', 'School Social Worker', 'Licensed', 'Active'],
  ['Healthcare', 'Social Work', 'Medical Social Worker', 'Licensed', 'Active'],
  ['Healthcare', 'Social Work', 'Psychiatric Social Worker', 'Licensed', 'Active'],
  ['Healthcare', 'Social Work', 'Geriatric Social Worker', 'Certified', 'Active'],
  ['Healthcare', 'Social Work', 'Pediatric Social Worker', 'Certified', 'Active'],
  ['Healthcare', 'Social Work', 'Community Social Worker', 'Licensed', 'Active'],
  ['Healthcare', 'Social Work', 'Clinical Social Worker (CSW)', 'Licensed', 'Temporary'],
  ['Healthcare', 'Social Work', 'Social Work Case Manager', 'Certified', 'Active'],
];

// ============================================
// SAMPLE 2: Master Taxonomy - Nurse Practitioners
// ============================================

const nursePractitionersMasterData = [
  // Header row
  ['Industry (node)', 'Group (node)', 'Occupation (node)', 'Specialty (node)', 'Level (attribute)', 'Status (attribute)'],

  // Data rows
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Family Practice', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Adult-Gerontology', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Pediatrics', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Psychiatric-Mental Health', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Womens Health', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Acute Care', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Neonatal', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Emergency', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Oncology', 'Advanced Practice', 'Active'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Cardiology', 'Advanced Practice', 'Active'],

  // Some with temporary status
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Family Practice', 'Advanced Practice', 'Temporary'],
  ['Healthcare', 'Nursing', 'Nurse Practitioner', 'Family Practice', 'Provisional', 'Active'],
];

// ============================================
// SAMPLE 3: Customer Taxonomy - Hospital A
// ============================================

const hospitalACustomerData = [
  // Header row (customer format - profession column marker)
  ['Job Title (profession)', 'State', 'Years Experience', 'Department'],

  // Data rows
  ['Licensed Clinical Social Worker', 'CA', '5', 'Mental Health'],
  ['LCSW', 'CA', '3', 'Emergency'],
  ['Licensed Social Worker', 'WA', '2', 'Pediatrics'],
  ['Clinical Social Worker', 'NY', '8', 'Oncology'],
  ['MSW', 'FL', '1', 'General'],
  ['Social Work Supervisor', 'TX', '10', 'Administration'],
  ['Family Nurse Practitioner', 'CA', '7', 'Primary Care'],
  ['Psychiatric NP', 'CA', '4', 'Mental Health'],
  ['Pediatric Nurse Practitioner', 'WA', '6', 'Pediatrics'],
  ['Acute Care Nurse Practitioner', 'NY', '9', 'ICU'],
];

// ============================================
// API Event Payloads
// ============================================

export const sampleApiEvents = {
  masterSocialWork: {
    source: 'api' as const,
    taxonomyType: 'master' as const,
    payload: {
      customer_id: '-1',
      taxonomy_id: '-1',
      taxonomy_name: 'Propelus Master Taxonomy - Social Work',
      layout: {
        Nodes: ['Industry', 'Group', 'Occupation'],
        Attributes: ['Level', 'Status']
      },
      rows: socialWorkMasterData.slice(1).map(row => ({
        'Industry': row[0],
        'Group': row[1],
        'Occupation': row[2],
        'Level': row[3],
        'Status': row[4]
      }))
    }
  },

  masterNursePractitioners: {
    source: 'api' as const,
    taxonomyType: 'master' as const,
    payload: {
      customer_id: '-1',
      taxonomy_id: '-1',
      taxonomy_name: 'Propelus Master Taxonomy - Nurse Practitioners',
      layout: {
        Nodes: ['Industry', 'Group', 'Occupation', 'Specialty'],
        Attributes: ['Level', 'Status']
      },
      rows: nursePractitionersMasterData.slice(1).map(row => ({
        'Industry': row[0],
        'Group': row[1],
        'Occupation': row[2],
        'Specialty': row[3],
        'Level': row[4],
        'Status': row[5]
      }))
    }
  },

  customerHospitalA: {
    source: 'api' as const,
    taxonomyType: 'customer' as const,
    payload: {
      customer_id: '100',
      taxonomy_id: '200',
      taxonomy_name: 'Hospital A Professions',
      layout: {
        'Proffesion column': {
          Profession: 'Job Title'
        }
      },
      rows: hospitalACustomerData.slice(1).map(row => ({
        'Job Title': row[0],
        'State': row[1],
        'Years Experience': row[2],
        'Department': row[3]
      }))
    }
  }
};

// ============================================
// S3 Event Generator
// ============================================

export const sampleS3Events = {
  masterSocialWork: {
    source: 's3' as const,
    taxonomyType: 'master' as const,
    bucket: 'propelus-taxonomy-uploads',
    key: 'customer--1__taxonomy--1__master-social-work.xlsx'
  },

  masterNursePractitioners: {
    source: 's3' as const,
    taxonomyType: 'master' as const,
    bucket: 'propelus-taxonomy-uploads',
    key: 'customer--1__taxonomy--1__master-nurse-practitioners.xlsx'
  },

  customerHospitalA: {
    source: 's3' as const,
    taxonomyType: 'customer' as const,
    bucket: 'propelus-taxonomy-uploads',
    key: 'customer-100__taxonomy-200__hospital-a-professions.xlsx'
  }
};

// ============================================
// Excel File Generator
// ============================================

export function generateExcelFile(
  data: any[][],
  outputPath: string
): void {
  // Create workbook
  const workbook = XLSX.utils.book_new();

  // Create worksheet
  const worksheet = XLSX.utils.aoa_to_sheet(data);

  // Add worksheet to workbook
  XLSX.utils.book_append_sheet(workbook, worksheet, 'Taxonomy');

  // Ensure output directory exists
  const dir = path.dirname(outputPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  // Write file
  XLSX.writeFile(workbook, outputPath);
  console.log(`✅ Generated Excel file: ${outputPath}`);
}

// ============================================
// Main Generator Function
// ============================================

export function generateAllTestData(outputDir: string = './test-data'): void {
  console.log('🚀 Generating test data files...\n');

  // Create Excel files
  generateExcelFile(
    socialWorkMasterData,
    path.join(outputDir, 'master-social-work.xlsx')
  );

  generateExcelFile(
    nursePractitionersMasterData,
    path.join(outputDir, 'master-nurse-practitioners.xlsx')
  );

  generateExcelFile(
    hospitalACustomerData,
    path.join(outputDir, 'customer-hospital-a.xlsx')
  );

  // Create JSON files for API events
  const apiEventsPath = path.join(outputDir, 'api-events.json');
  fs.writeFileSync(
    apiEventsPath,
    JSON.stringify(sampleApiEvents, null, 2)
  );
  console.log(`✅ Generated API events: ${apiEventsPath}`);

  // Create JSON files for S3 events
  const s3EventsPath = path.join(outputDir, 's3-events.json');
  fs.writeFileSync(
    s3EventsPath,
    JSON.stringify(sampleS3Events, null, 2)
  );
  console.log(`✅ Generated S3 events: ${s3EventsPath}`);

  console.log('\n✨ Test data generation complete!\n');
  console.log('📁 Files generated:');
  console.log(`   - ${outputDir}/master-social-work.xlsx`);
  console.log(`   - ${outputDir}/master-nurse-practitioners.xlsx`);
  console.log(`   - ${outputDir}/customer-hospital-a.xlsx`);
  console.log(`   - ${outputDir}/api-events.json`);
  console.log(`   - ${outputDir}/s3-events.json`);
}

// ============================================
// CLI Usage
// ============================================

if (require.main === module) {
  const outputDir = process.argv[2] || './test-data';
  generateAllTestData(outputDir);
}

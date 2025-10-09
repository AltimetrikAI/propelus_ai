#!/usr/bin/env python3
"""
Update Confluence Space with Latest Lambda Implementation
Fetches all pages in the Propelus AI space and updates with current status
"""

import requests
import json
from typing import List, Dict, Any

# Configuration
CONFLUENCE_BASE_URL = "https://altimetrik.atlassian.net/wiki"
SPACE_KEY = "PA1"
API_TOKEN = "ATATT3xFfGF0UQKFBg9KRo0PUhl2Ny7toXxvwKmLszc9E4Xfoub-1grp4ODbJyXjiAceoDG_gewlCQw81k57VB-_k4_ggjEXcSx8YZ3xJ1TX7k1NKbA6VPKhwmNpgAmQN-r-FtfAf2AV5I9R6ljATvtoxbM4nmI_T2XpUgxHlJoOxqbiLrqiMSc=0DB63BE1"
EMAIL = "douglas.martins@propelus.ai"  # Update with actual email if different

# Use Basic Auth with email and API token
from requests.auth import HTTPBasicAuth

# Auth object
AUTH = HTTPBasicAuth(EMAIL, API_TOKEN)

# Headers for API requests
HEADERS = {
    "Content-Type": "application/json",
    "Accept": "application/json"
}

def get_all_pages_in_space(space_key: str) -> List[Dict[str, Any]]:
    """Fetch all pages in a Confluence space"""
    url = f"{CONFLUENCE_BASE_URL}/rest/api/content"
    params = {
        "spaceKey": space_key,
        "limit": 100,
        "expand": "version,body.storage"
    }

    all_pages = []

    try:
        while True:
            response = requests.get(url, auth=AUTH, headers=HEADERS, params=params)
            response.raise_for_status()

            data = response.json()
            all_pages.extend(data.get("results", []))

            # Check if there are more pages
            if "next" in data.get("_links", {}):
                url = CONFLUENCE_BASE_URL + data["_links"]["next"]
                params = {}  # Parameters are in the next URL
            else:
                break

        return all_pages
    except requests.exceptions.RequestException as e:
        print(f"Error fetching pages: {e}")
        return []

def get_page_content(page_id: str) -> Dict[str, Any]:
    """Fetch full page content"""
    url = f"{CONFLUENCE_BASE_URL}/rest/api/content/{page_id}"
    params = {
        "expand": "body.storage,version,space"
    }

    try:
        response = requests.get(url, auth=AUTH, headers=HEADERS, params=params)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching page {page_id}: {e}")
        return {}

def update_page(page_id: str, title: str, content: str, version: int) -> bool:
    """Update a Confluence page"""
    url = f"{CONFLUENCE_BASE_URL}/rest/api/content/{page_id}"

    payload = {
        "version": {
            "number": version + 1,
            "message": "Updated with latest Lambda implementation status"
        },
        "title": title,
        "type": "page",
        "body": {
            "storage": {
                "value": content,
                "representation": "storage"
            }
        }
    }

    try:
        response = requests.put(url, auth=AUTH, headers=HEADERS, json=payload)
        response.raise_for_status()
        print(f"✅ Updated page: {title}")
        return True
    except requests.exceptions.RequestException as e:
        print(f"❌ Error updating page {title}: {e}")
        if hasattr(e.response, 'text'):
            print(f"   Response: {e.response.text}")
        return False

def create_lambda_status_section() -> str:
    """Generate HTML content for Lambda status update"""
    return """
<ac:structured-macro ac:name="info">
  <ac:rich-text-body>
    <p><strong>Last Updated:</strong> October 3, 2025</p>
    <p><strong>Author:</strong> Douglas Martins, Senior AI Engineer/Architect</p>
  </ac:rich-text-body>
</ac:structured-macro>

<h2>🚀 Latest Updates - Ingestion &amp; Cleansing Lambda v2.0</h2>

<ac:structured-macro ac:name="panel" ac:schema-version="1">
  <ac:parameter ac:name="bgColor">#deebff</ac:parameter>
  <ac:rich-text-body>
    <p><strong>✅ COMPLETED:</strong> Combined Ingestion &amp; Cleansing Lambda v2.0</p>
    <ul>
      <li>Atomic Bronze → Silver transformation in single transaction</li>
      <li>25 TypeScript modules implementing data engineer's algorithm v0.2</li>
      <li>Two-path processing (NEW insert-only, UPDATED upsert + soft-delete)</li>
      <li>Complete versioning system with affected nodes/attributes tracking</li>
      <li>Comprehensive test suite with sample data generation</li>
    </ul>
  </ac:rich-text-body>
</ac:structured-macro>

<h3>📦 Implementation Summary</h3>

<table>
  <tbody>
    <tr>
      <th>Component</th>
      <th>Status</th>
      <th>Files</th>
      <th>Details</th>
    </tr>
    <tr>
      <td><strong>Type Definitions</strong></td>
      <td><ac:structured-macro ac:name="status"><ac:parameter ac:name="color">Green</ac:parameter><ac:parameter ac:name="title">COMPLETE</ac:parameter></ac:structured-macro></td>
      <td>4 files</td>
      <td>Events, layouts, context, cache</td>
    </tr>
    <tr>
      <td><strong>Utilities</strong></td>
      <td><ac:structured-macro ac:name="status"><ac:parameter ac:name="color">Green</ac:parameter><ac:parameter ac:name="title">COMPLETE</ac:parameter></ac:structured-macro></td>
      <td>3 files</td>
      <td>Normalization (§0), streams, constants</td>
    </tr>
    <tr>
      <td><strong>Parsers</strong></td>
      <td><ac:structured-macro ac:name="status"><ac:parameter ac:name="color">Green</ac:parameter><ac:parameter ac:name="title">COMPLETE</ac:parameter></ac:structured-macro></td>
      <td>4 files</td>
      <td>Excel, API, layout, filename (§2.2, §4)</td>
    </tr>
    <tr>
      <td><strong>Database Queries</strong></td>
      <td><ac:structured-macro ac:name="status"><ac:parameter ac:name="color">Green</ac:parameter><ac:parameter ac:name="title">COMPLETE</ac:parameter></ac:structured-macro></td>
      <td>8 files</td>
      <td>Load, bronze, silver, dictionaries (§6), versioning (§7A.3, §7B.5), reconciliation (§7B.3-4)</td>
    </tr>
    <tr>
      <td><strong>Processors</strong></td>
      <td><ac:structured-macro ac:name="status"><ac:parameter ac:name="color">Green</ac:parameter><ac:parameter ac:name="title">COMPLETE</ac:parameter></ac:structured-macro></td>
      <td>4 files</td>
      <td>S3, API, row processor (§7), orchestrator (§1-§8)</td>
    </tr>
    <tr>
      <td><strong>Test Suite</strong></td>
      <td><ac:structured-macro ac:name="status"><ac:parameter ac:name="color">Green</ac:parameter><ac:parameter ac:name="title">COMPLETE</ac:parameter></ac:structured-macro></td>
      <td>3 files</td>
      <td>Sample data generator, validator, local runner</td>
    </tr>
    <tr>
      <td><strong>Documentation</strong></td>
      <td><ac:structured-macro ac:name="status"><ac:parameter ac:name="color">Green</ac:parameter><ac:parameter ac:name="title">COMPLETE</ac:parameter></ac:structured-macro></td>
      <td>3 files</td>
      <td>Lambda README, log retention strategy, master taxonomy attributes</td>
    </tr>
  </tbody>
</table>

<h3>🎯 Key Technical Features</h3>

<ac:structured-macro ac:name="expand">
  <ac:parameter ac:name="title">Technical Implementation Details</ac:parameter>
  <ac:rich-text-body>
    <h4>Two-Path Processing Logic</h4>
    <ul>
      <li><strong>NEW Load:</strong> Insert-only, no reactivation, creates Version 1</li>
      <li><strong>UPDATED Load:</strong> Upsert with soft-delete reconciliation, creates Version N</li>
    </ul>

    <h4>Natural Key Constraints (Case-Insensitive)</h4>
    <ul>
      <li><strong>Nodes:</strong> (taxonomy_id, node_type_id, customer_id, LOWER(value))</li>
      <li><strong>Attributes:</strong> (node_id, attribute_type_id, LOWER(value))</li>
    </ul>

    <h4>Append-Only Dictionaries</h4>
    <ul>
      <li>silver_taxonomies_nodes_types - never modified, only INSERT</li>
      <li>silver_taxonomies_attribute_types - never modified, only INSERT</li>
    </ul>

    <h4>Complete Audit Trail</h4>
    <ul>
      <li>Row-level lineage with load_id and row_id</li>
      <li>Row-level error tracking in load_details JSON</li>
      <li>Version history with affected nodes/attributes</li>
    </ul>
  </ac:rich-text-body>
</ac:structured-macro>

<h3>📊 Project Status</h3>

<ac:structured-macro ac:name="status"><ac:parameter ac:name="color">Green</ac:parameter><ac:parameter ac:name="title">90% COMPLETE</ac:parameter></ac:structured-macro>

<p><strong>GitHub Repository:</strong> <a href="https://github.com/AltimetrikAI/propelus_ai">https://github.com/AltimetrikAI/propelus_ai</a></p>

<p><strong>Latest Commits:</strong></p>
<ul>
  <li><code>80b67bf</code> - Add all implementation modules (21 files, 1,389 lines)</li>
  <li><code>0100a6d</code> - Combined Ingestion &amp; Cleansing Lambda v2.0 (14 files, 2,551 lines)</li>
</ul>

<h3>⏳ Next Steps</h3>

<ac:structured-macro ac:name="panel" ac:schema-version="1">
  <ac:parameter ac:name="bgColor">#fffae6</ac:parameter>
  <ac:rich-text-body>
    <ol>
      <li><strong>Database Migrations</strong> - Awaiting physical data model from Marcin (Monday)</li>
      <li><strong>Integration Testing</strong> - Test with sample taxonomies (Social Work, Nurse Practitioners)</li>
      <li><strong>Tuesday Walkthrough</strong> - Demo with Kristen's sample data</li>
      <li><strong>Step Functions Update</strong> - Modify workflow to call combined Lambda</li>
    </ol>
  </ac:rich-text-body>
</ac:structured-macro>

<h3>📚 Documentation</h3>

<ul>
  <li><a href="https://github.com/AltimetrikAI/propelus_ai/blob/main/lambdas/ingestion_and_cleansing/README.md">Lambda README</a> - Architecture and usage guide</li>
  <li><a href="https://github.com/AltimetrikAI/propelus_ai/blob/main/docs/LOG_RETENTION_STRATEGY.md">Log Retention Strategy</a> - Audit log compliance approach</li>
  <li><a href="https://github.com/AltimetrikAI/propelus_ai/blob/main/lambdas/ingestion_and_cleansing/test/README.md">Test Suite README</a> - Sample data generation and testing</li>
  <li><a href="https://github.com/AltimetrikAI/propelus_ai/blob/main/PROJECT_DOCUMENTATION.md">Project Documentation</a> - Complete system architecture</li>
</ul>

<hr/>
"""

def main():
    """Main execution"""
    print("🔍 Fetching pages from Confluence space...")
    pages = get_all_pages_in_space(SPACE_KEY)

    if not pages:
        print("❌ No pages found or error occurred")
        return

    print(f"✅ Found {len(pages)} pages in space {SPACE_KEY}\n")

    # Display pages
    print("📄 Pages in space:")
    for i, page in enumerate(pages, 1):
        print(f"   {i}. {page['title']} (ID: {page['id']})")

    print("\n" + "="*60)
    print("📝 Updating pages with Lambda status...")
    print("="*60 + "\n")

    lambda_status_content = create_lambda_status_section()

    for page in pages:
        page_id = page['id']
        page_title = page['title']

        # Fetch full page content
        full_page = get_page_content(page_id)

        if not full_page:
            continue

        current_version = full_page['version']['number']
        current_content = full_page['body']['storage']['value']

        # Check if page already has Lambda status section
        if "Ingestion &amp; Cleansing Lambda v2.0" in current_content:
            print(f"⏭️  Skipping {page_title} (already has latest update)")
            continue

        # Prepend Lambda status to existing content
        updated_content = lambda_status_content + "\n\n" + current_content

        # Update the page
        success = update_page(page_id, page_title, updated_content, current_version)

        if success:
            print(f"   Version: {current_version} → {current_version + 1}\n")

    print("="*60)
    print("✅ Confluence update complete!")
    print("="*60)

if __name__ == "__main__":
    main()

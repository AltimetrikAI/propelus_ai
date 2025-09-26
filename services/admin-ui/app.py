"""
Propelus Taxonomy Admin UI
Human-in-the-Loop interface for taxonomy management and translation review
"""

import streamlit as st
import pandas as pd
import requests
from datetime import datetime, timedelta
import plotly.express as px
import plotly.graph_objects as go
from typing import Optional, List, Dict
import asyncio
import json
import time

# Page configuration
st.set_page_config(
    page_title="Propelus Taxonomy Admin",
    page_icon="🏥",
    layout="wide",
    initial_sidebar_state="expanded"
)

# API Configuration
API_BASE_URL = st.secrets.get("API_BASE_URL", "http://localhost:8000/api/v1")
TRANSLATION_API_URL = st.secrets.get("TRANSLATION_API_URL", "http://localhost:8001/api/v1")

# Authentication check
def check_auth():
    if "authenticated" not in st.session_state:
        st.session_state.authenticated = False
    
    if not st.session_state.authenticated:
        with st.container():
            st.title("🔐 Login")
            col1, col2, col3 = st.columns([1, 2, 1])
            with col2:
                username = st.text_input("Username")
                password = st.text_input("Password", type="password")
                if st.button("Login", use_container_width=True):
                    # TODO: Implement actual authentication
                    if username and password:
                        st.session_state.authenticated = True
                        st.session_state.user = username
                        st.rerun()
                    else:
                        st.error("Invalid credentials")
        return False
    return True


# API Helper Functions
def make_api_request(endpoint: str, method: str = "GET", data: dict = None, params: dict = None):
    """Make API request with error handling"""
    try:
        url = f"{API_BASE_URL}/{endpoint.lstrip('/')}"

        if method == "GET":
            response = requests.get(url, params=params)
        elif method == "POST":
            response = requests.post(url, json=data, params=params)
        elif method == "PUT":
            response = requests.put(url, json=data, params=params)
        elif method == "DELETE":
            response = requests.delete(url, params=params)

        if response.status_code == 200:
            return response.json()
        else:
            st.error(f"API Error: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        st.error(f"Connection error: {str(e)}")
        return None


def get_dashboard_stats(customer_id: Optional[int] = None):
    """Get dashboard statistics"""
    params = {'customer_id': customer_id} if customer_id else {}
    return make_api_request("admin/dashboard", params=params)


def get_review_queue(customer_id: Optional[int] = None, limit: int = 50):
    """Get review queue items"""
    params = {'limit': limit}
    if customer_id:
        params['customer_id'] = customer_id
    return make_api_request("admin/review-queue", params=params)


def approve_mapping(mapping_id: int, mapping_type: str, notes: str = ""):
    """Approve a mapping"""
    data = {'notes': notes}
    params = {'mapping_type': mapping_type}
    return make_api_request(f"mappings/{mapping_id}/approve", "POST", data, params)


def reject_mapping(mapping_id: int, mapping_type: str, reason: str, notes: str = ""):
    """Reject a mapping"""
    data = {'reason': reason, 'notes': notes}
    params = {'mapping_type': mapping_type}
    return make_api_request(f"mappings/{mapping_id}/reject", "POST", data, params)


# Dashboard Page
def show_dashboard():
    st.title("🏥 Propelus Taxonomy Dashboard")

    # Customer filter
    col1, col2, col3 = st.columns([2, 1, 1])
    with col1:
        customer_id = st.selectbox(
            "Filter by Customer",
            options=[None, 1, 2, 3, 4, 5],
            format_func=lambda x: "All Customers" if x is None else f"Customer {x}"
        )

    with col2:
        if st.button("🔄 Refresh", use_container_width=True):
            st.rerun()

    with col3:
        auto_refresh = st.checkbox("Auto-refresh (30s)")

    # Get dashboard data
    dashboard_data = get_dashboard_stats(customer_id)

    if dashboard_data:
        # Key metrics cards
        col1, col2, col3, col4 = st.columns(4)

        with col1:
            st.metric(
                "Review Queue",
                dashboard_data['review_queue']['pending_review'],
                delta=None,
                help="Mappings requiring human review"
            )

        with col2:
            st.metric(
                "Processing",
                dashboard_data['processing']['currently_processing'],
                delta=f"+{dashboard_data['processing']['processed_24h']} (24h)",
                help="Currently processing sources"
            )

        with col3:
            st.metric(
                "Active Taxonomies",
                dashboard_data['content']['active_taxonomies'],
                help="Number of active taxonomies"
            )

        with col4:
            st.metric(
                "Total Nodes",
                dashboard_data['content']['total_nodes'],
                help="Total taxonomy nodes across all taxonomies"
            )

        st.divider()

        # Charts section
        col1, col2 = st.columns(2)

        with col1:
            st.subheader("📊 Review Queue Distribution")

            review_data = dashboard_data['review_queue']
            fig = go.Figure(data=[
                go.Pie(
                    labels=['Pending Review', 'High Confidence', 'Active', 'Rejected'],
                    values=[
                        review_data['pending_review'],
                        review_data['high_confidence'],
                        review_data['active_mappings'],
                        review_data['rejected_mappings']
                    ],
                    hole=0.4
                )
            ])
            fig.update_layout(height=300)
            st.plotly_chart(fig, use_container_width=True)

        with col2:
            st.subheader("⚡ Processing Status")

            processing_data = dashboard_data['processing']
            fig = go.Figure(data=[
                go.Bar(
                    x=['Processing', 'Completed', 'Failed'],
                    y=[
                        processing_data['currently_processing'],
                        processing_data['completed'],
                        processing_data['failed']
                    ],
                    marker_color=['orange', 'green', 'red']
                )
            ])
            fig.update_layout(height=300, showlegend=False)
            st.plotly_chart(fig, use_container_width=True)

        # Recent activity
        st.subheader("🕒 Recent Activity")
        if dashboard_data['recent_activity']:
            activity_df = pd.DataFrame(dashboard_data['recent_activity'])
            st.dataframe(
                activity_df,
                use_container_width=True,
                hide_index=True
            )
        else:
            st.info("No recent activity to display")

    else:
        st.error("Failed to load dashboard data")

    # Auto-refresh logic
    if auto_refresh:
        time.sleep(30)
        st.rerun()


# Review Queue Page
def show_review_queue():
    st.title("👥 Human Review Queue")

    # Filters
    col1, col2, col3, col4 = st.columns(4)

    with col1:
        customer_id = st.selectbox(
            "Customer",
            options=[None, 1, 2, 3, 4, 5],
            format_func=lambda x: "All" if x is None else f"Customer {x}"
        )

    with col2:
        confidence_range = st.slider(
            "Confidence Range",
            min_value=0.0,
            max_value=100.0,
            value=(0.0, 89.0),
            step=1.0
        )

    with col3:
        sort_by = st.selectbox(
            "Sort by",
            options=['confidence_asc', 'confidence_desc', 'created_desc', 'customer'],
            format_func=lambda x: {
                'confidence_asc': 'Confidence (Low to High)',
                'confidence_desc': 'Confidence (High to Low)',
                'created_desc': 'Newest First',
                'customer': 'Customer'
            }[x]
        )

    with col4:
        limit = st.selectbox("Items per page", [25, 50, 100, 200], index=1)

    # Get review queue data
    params = {
        'customer_id': customer_id,
        'confidence_min': confidence_range[0],
        'confidence_max': confidence_range[1],
        'sort_by': sort_by,
        'limit': limit
    }

    review_data = make_api_request("admin/review-queue", params=params)

    if review_data and review_data['review_items']:
        st.info(f"Found {review_data['total']} items (showing {len(review_data['review_items'])})")

        # Process each review item
        for item in review_data['review_items']:
            with st.expander(
                f"🔍 {item['source_node']['value']} → {item['target_node']['value']} "
                f"({item['confidence']:.1f}% confidence)"
            ):
                # Item details
                col1, col2 = st.columns(2)

                with col1:
                    st.markdown("**Source Node:**")
                    st.write(f"• Value: {item['source_node']['value']}")
                    st.write(f"• Type: {item['source_node']['type']}")
                    st.write(f"• Level: {item['source_node']['level']}")
                    st.write(f"• Taxonomy: {item['source_node']['taxonomy']}")
                    st.write(f"• Customer: {item['source_node']['customer_id']}")

                    if item['source_node']['attributes']:
                        st.markdown("**Attributes:**")
                        for attr in item['source_node']['attributes']:
                            st.write(f"• {attr['name']}: {attr['value']}")

                with col2:
                    st.markdown("**Target Node:**")
                    st.write(f"• Value: {item['target_node']['value']}")
                    st.write(f"• Type: {item['target_node']['type']}")
                    st.write(f"• Level: {item['target_node']['level']}")
                    st.write(f"• Taxonomy: {item['target_node']['taxonomy']}")

                    if item['target_node']['attributes']:
                        st.markdown("**Attributes:**")
                        for attr in item['target_node']['attributes']:
                            st.write(f"• {attr['name']}: {attr['value']}")

                # Rule information
                if item['rule_info']['rule_name']:
                    st.markdown("**Mapping Rule:**")
                    st.write(f"• Rule: {item['rule_info']['rule_name']}")
                    st.write(f"• Type: {item['rule_info']['rule_type']}")

                # Alternative suggestions
                if item['alternatives']:
                    st.markdown("**Alternative Suggestions:**")
                    alt_df = pd.DataFrame(item['alternatives'])
                    st.dataframe(alt_df, use_container_width=True, hide_index=True)

                # Action buttons
                col1, col2, col3, col4 = st.columns([1, 1, 2, 2])

                with col1:
                    if st.button(f"✅ Approve", key=f"approve_{item['mapping_id']}"):
                        result = approve_mapping(
                            item['mapping_id'],
                            'taxonomy',
                            f"Approved by {st.session_state.user}"
                        )
                        if result:
                            st.success("Mapping approved!")
                            st.rerun()

                with col2:
                    if st.button(f"❌ Reject", key=f"reject_{item['mapping_id']}"):
                        st.session_state[f"show_reject_{item['mapping_id']}"] = True

                # Rejection form
                if st.session_state.get(f"show_reject_{item['mapping_id']}", False):
                    with col3:
                        reason = st.text_input(
                            "Reason for rejection",
                            key=f"reason_{item['mapping_id']}"
                        )
                    with col4:
                        if st.button(f"Confirm Reject", key=f"confirm_reject_{item['mapping_id']}"):
                            if reason:
                                result = reject_mapping(
                                    item['mapping_id'],
                                    'taxonomy',
                                    reason,
                                    f"Rejected by {st.session_state.user}"
                                )
                                if result:
                                    st.success("Mapping rejected!")
                                    st.rerun()
                            else:
                                st.error("Please provide a reason for rejection")

    else:
        st.info("No items in review queue with current filters")


# Translation Testing Page
def show_translation_testing():
    st.title("🔄 Translation Testing")

    # Single translation test
    st.subheader("Single Translation Test")

    col1, col2 = st.columns(2)

    with col1:
        source_taxonomy = st.text_input(
            "Source Taxonomy",
            value="customer_1",
            help="e.g., customer_1, master, or taxonomy name"
        )
        source_code = st.text_input(
            "Source Code",
            value="RN",
            help="Code to translate"
        )

    with col2:
        target_taxonomy = st.text_input(
            "Target Taxonomy",
            value="master",
            help="e.g., customer_2, master, or taxonomy name"
        )

        # Attributes
        st.markdown("**Attributes (JSON format):**")
        attributes_json = st.text_area(
            "Attributes",
            value='{"state": "CA", "license_type": "active"}',
            height=100,
            help="Additional context for translation"
        )

    # Options
    col1, col2 = st.columns(2)
    with col1:
        include_alternatives = st.checkbox("Include alternatives", value=True)
    with col2:
        min_confidence = st.slider("Minimum confidence", 0.0, 100.0, 70.0)

    if st.button("🔄 Translate", use_container_width=True, type="primary"):
        try:
            attributes = json.loads(attributes_json)

            translation_data = {
                'source_taxonomy': source_taxonomy,
                'target_taxonomy': target_taxonomy,
                'source_code': source_code,
                'attributes': attributes,
                'options': {
                    'include_alternatives': include_alternatives,
                    'min_confidence': min_confidence
                }
            }

            # Make translation request
            response = make_api_request("translate", "POST", translation_data)

            if response:
                st.success(f"Translation completed in {response.get('processing_time_ms', 0)}ms")

                # Display results
                if response.get('source_match'):
                    st.subheader("Source Match")
                    st.json(response['source_match'])

                st.subheader("Translation Results")
                if response.get('matches'):
                    results_df = pd.DataFrame(response['matches'])
                    st.dataframe(results_df, use_container_width=True)
                else:
                    st.warning("No translation matches found")

                # Full response details
                with st.expander("Full Response Details"):
                    st.json(response)

        except json.JSONDecodeError:
            st.error("Invalid JSON format in attributes")
        except Exception as e:
            st.error(f"Translation error: {str(e)}")


# Main App
def main():
    if not check_auth():
        return

    # Sidebar navigation
    st.sidebar.title(f"Welcome, {st.session_state.user}! 👋")

    pages = {
        "📊 Dashboard": show_dashboard,
        "👥 Review Queue": show_review_queue,
        "🔄 Translation Testing": show_translation_testing,
    }

    selected_page = st.sidebar.selectbox("Navigate to:", list(pages.keys()))

    # Logout button
    if st.sidebar.button("🚪 Logout"):
        st.session_state.authenticated = False
        st.rerun()

    # Show selected page
    pages[selected_page]()


if __name__ == "__main__":
    main()

# Sidebar navigation
def render_sidebar():
    with st.sidebar:
        st.title("🏥 Taxonomy Admin")
        st.markdown("---")
        
        # User info
        if "user" in st.session_state:
            st.write(f"👤 **User:** {st.session_state.user}")
            if st.button("Logout"):
                st.session_state.authenticated = False
                st.rerun()
        
        st.markdown("---")
        
        # Navigation menu
        st.subheader("Navigation")
        page = st.radio(
            "Select Page",
            [
                "📊 Dashboard",
                "🏢 Profession Management",
                "🔄 Translation Review",
                "📝 Audit Logs",
                "⚙️ Settings"
            ],
            label_visibility="collapsed"
        )
        
        st.markdown("---")
        
        # Quick stats
        st.subheader("Quick Stats")
        col1, col2 = st.columns(2)
        with col1:
            st.metric("Total Professions", "1,234")
            st.metric("Pending Reviews", "45")
        with col2:
            st.metric("Today's Translations", "892")
            st.metric("Accuracy Rate", "94.3%")
        
        return page

# Dashboard page
def render_dashboard():
    st.title("📊 Taxonomy Dashboard")
    
    # Date range filter
    col1, col2, col3, col4 = st.columns([1, 1, 1, 2])
    with col1:
        start_date = st.date_input("Start Date", datetime.now() - timedelta(days=7))
    with col2:
        end_date = st.date_input("End Date", datetime.now())
    
    st.markdown("---")
    
    # Metrics row
    col1, col2, col3, col4 = st.columns(4)
    
    with col1:
        st.metric(
            "Total Translations",
            "15,234",
            delta="↑ 12.3%",
            delta_color="normal"
        )
    
    with col2:
        st.metric(
            "Average Confidence",
            "0.873",
            delta="↑ 0.021",
            delta_color="normal"
        )
    
    with col3:
        st.metric(
            "Review Rate",
            "8.2%",
            delta="↓ 1.5%",
            delta_color="inverse"
        )
    
    with col4:
        st.metric(
            "API Response Time",
            "145ms",
            delta="↓ 23ms",
            delta_color="inverse"
        )
    
    # Charts
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Translation Volume Over Time")
        # Sample data
        dates = pd.date_range(start=start_date, end=end_date, freq='D')
        volumes = [892 + i*50 for i in range(len(dates))]
        df_volume = pd.DataFrame({'Date': dates, 'Volume': volumes})
        
        fig = px.line(df_volume, x='Date', y='Volume', 
                     title="Daily Translation Volume")
        st.plotly_chart(fig, use_container_width=True)
    
    with col2:
        st.subheader("Translation Methods Distribution")
        methods_data = {
            'Method': ['AI', 'Exact Match', 'Fuzzy Match', 'Manual', 'Rule-based'],
            'Count': [4521, 3892, 2156, 892, 1773]
        }
        df_methods = pd.DataFrame(methods_data)
        
        fig = px.pie(df_methods, values='Count', names='Method',
                    title="Translation Method Usage")
        st.plotly_chart(fig, use_container_width=True)
    
    # Confidence distribution
    st.subheader("Confidence Score Distribution")
    confidence_scores = [0.95, 0.87, 0.92, 0.78, 0.99, 0.83, 0.91, 0.76, 0.88, 0.94] * 100
    
    fig = go.Figure(data=[go.Histogram(x=confidence_scores, nbinsx=20)])
    fig.update_layout(
        title="Distribution of Translation Confidence Scores",
        xaxis_title="Confidence Score",
        yaxis_title="Count"
    )
    st.plotly_chart(fig, use_container_width=True)

# Profession Management page
def render_profession_management():
    st.title("🏢 Profession Management")
    
    tab1, tab2, tab3 = st.tabs(["Browse Taxonomy", "Add Profession", "Edit Profession"])
    
    with tab1:
        st.subheader("Taxonomy Hierarchy")
        
        # Search and filter
        col1, col2, col3 = st.columns([2, 1, 1])
        with col1:
            search_term = st.text_input("Search professions", placeholder="Enter profession name or code")
        with col2:
            status_filter = st.selectbox("Status", ["All", "Active", "Inactive", "Deprecated"])
        with col3:
            level_filter = st.selectbox("Level", ["All", "0", "1", "2", "3", "4"])
        
        # Tree view simulation
        with st.expander("Healthcare Professions", expanded=True):
            col1, col2 = st.columns([3, 1])
            with col1:
                st.write("📁 **Medical Practitioners**")
                st.write("　　📄 Physician (MD)")
                st.write("　　📄 Surgeon")
                st.write("　　📄 Anesthesiologist")
            with col2:
                if st.button("Edit", key="edit_medical"):
                    st.info("Edit Medical Practitioners")
        
        with st.expander("Nursing Professions"):
            col1, col2 = st.columns([3, 1])
            with col1:
                st.write("📁 **Registered Nurses**")
                st.write("　　📄 Critical Care Nurse")
                st.write("　　📄 Pediatric Nurse")
                st.write("　　📄 Surgical Nurse")
            with col2:
                if st.button("Edit", key="edit_nursing"):
                    st.info("Edit Nursing Professions")
    
    with tab2:
        st.subheader("Add New Profession")
        
        col1, col2 = st.columns(2)
        
        with col1:
            code = st.text_input("Profession Code*", placeholder="e.g., PHY-001")
            name = st.text_input("Profession Name*", placeholder="e.g., Physician")
            display_name = st.text_input("Display Name*", placeholder="e.g., Medical Doctor")
            parent = st.selectbox("Parent Profession", ["None", "Medical Practitioners", "Nursing", "Allied Health"])
        
        with col2:
            status = st.selectbox("Status", ["Active", "Inactive"])
            regulatory_body = st.text_input("Regulatory Body", placeholder="e.g., State Medical Board")
            license_required = st.checkbox("License Required")
            description = st.text_area("Description")
        
        if st.button("Add Profession", type="primary"):
            st.success("Profession added successfully!")
    
    with tab3:
        st.subheader("Edit Existing Profession")
        
        profession_to_edit = st.selectbox(
            "Select Profession to Edit",
            ["Physician (PHY-001)", "Registered Nurse (RN-001)", "Physical Therapist (PT-001)"]
        )
        
        if profession_to_edit:
            col1, col2 = st.columns(2)
            
            with col1:
                code = st.text_input("Profession Code*", value="PHY-001")
                name = st.text_input("Profession Name*", value="Physician")
                display_name = st.text_input("Display Name*", value="Medical Doctor")
            
            with col2:
                status = st.selectbox("Status", ["Active", "Inactive"], index=0)
                regulatory_body = st.text_input("Regulatory Body", value="State Medical Board")
                license_required = st.checkbox("License Required", value=True)
            
            if st.button("Update Profession", type="primary"):
                st.success("Profession updated successfully!")

# Translation Review page
def render_translation_review():
    st.title("🔄 Translation Review")
    
    # Filters
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        review_status = st.selectbox("Review Status", ["Pending", "Approved", "Rejected", "All"])
    with col2:
        confidence_range = st.slider("Confidence Range", 0.0, 1.0, (0.0, 0.7))
    with col3:
        method_filter = st.multiselect("Translation Method", ["AI", "Exact", "Fuzzy", "Manual", "Rule-based"])
    with col4:
        date_filter = st.date_input("Date", datetime.now())
    
    st.markdown("---")
    
    # Review queue
    st.subheader("Review Queue")
    
    # Sample data
    review_data = {
        'Input': ['RN', 'Physical Therapy Assistant', 'Dental Hygiene', 'MD Surgeon', 'Nurse Practitioner'],
        'Matched': ['Registered Nurse', 'Physical Therapist Assistant', 'Dental Hygienist', 'Physician', 'Advanced Practice Nurse'],
        'Confidence': [0.95, 0.67, 0.72, 0.89, 0.65],
        'Method': ['Exact', 'AI', 'Fuzzy', 'AI', 'AI'],
        'Time': ['2 min ago', '5 min ago', '12 min ago', '15 min ago', '18 min ago']
    }
    
    df_review = pd.DataFrame(review_data)
    
    for idx, row in df_review.iterrows():
        with st.container():
            col1, col2, col3, col4, col5 = st.columns([2, 2, 1, 1, 2])
            
            with col1:
                st.write(f"**Input:** {row['Input']}")
            
            with col2:
                st.write(f"**Matched:** {row['Matched']}")
            
            with col3:
                confidence_color = "🟢" if row['Confidence'] > 0.8 else "🟡" if row['Confidence'] > 0.6 else "🔴"
                st.write(f"{confidence_color} {row['Confidence']:.2f}")
            
            with col4:
                st.write(f"**{row['Method']}**")
            
            with col5:
                col_a, col_b, col_c = st.columns(3)
                with col_a:
                    if st.button("✅ Approve", key=f"approve_{idx}"):
                        st.success("Approved!")
                with col_b:
                    if st.button("❌ Reject", key=f"reject_{idx}"):
                        st.error("Rejected")
                with col_c:
                    if st.button("✏️ Edit", key=f"edit_{idx}"):
                        st.info("Edit mode")
            
            st.markdown("---")

# Audit Logs page
def render_audit_logs():
    st.title("📝 Audit Logs")
    
    # Filters
    col1, col2, col3, col4 = st.columns(4)
    with col1:
        entity_type = st.selectbox("Entity Type", ["All", "Profession", "Translation", "User"])
    with col2:
        action = st.selectbox("Action", ["All", "Create", "Update", "Delete", "Approve", "Reject"])
    with col3:
        user_filter = st.text_input("User", placeholder="Enter username")
    with col4:
        date_range = st.date_input("Date Range", [datetime.now() - timedelta(days=7), datetime.now()])
    
    st.markdown("---")
    
    # Audit log table
    audit_data = {
        'Timestamp': pd.date_range(end=datetime.now(), periods=10, freq='H'),
        'User': ['admin', 'john.doe', 'admin', 'jane.smith', 'admin'] * 2,
        'Action': ['Update', 'Create', 'Approve', 'Delete', 'Update'] * 2,
        'Entity': ['Profession', 'Translation', 'Translation', 'Alias', 'Profession'] * 2,
        'Details': ['Updated status to active', 'Created new translation', 'Approved translation', 'Deleted alias', 'Updated hierarchy'] * 2
    }
    
    df_audit = pd.DataFrame(audit_data)
    
    st.dataframe(
        df_audit,
        use_container_width=True,
        hide_index=True,
        column_config={
            "Timestamp": st.column_config.DatetimeColumn(
                "Timestamp",
                format="DD/MM/YYYY HH:mm:ss"
            )
        }
    )

# Settings page
def render_settings():
    st.title("⚙️ Settings")
    
    tab1, tab2, tab3, tab4 = st.tabs(["API Configuration", "Translation Settings", "User Management", "System"])
    
    with tab1:
        st.subheader("API Configuration")
        
        col1, col2 = st.columns(2)
        with col1:
            st.text_input("Taxonomy API URL", value=API_BASE_URL)
            st.text_input("Translation API URL", value=TRANSLATION_API_URL)
            st.number_input("Request Timeout (seconds)", value=30, min_value=5, max_value=300)
        
        with col2:
            st.text_input("API Key", type="password", value="********")
            st.number_input("Rate Limit (requests/min)", value=100, min_value=10, max_value=1000)
            st.checkbox("Enable Caching", value=True)
    
    with tab2:
        st.subheader("Translation Settings")
        
        col1, col2 = st.columns(2)
        with col1:
            st.slider("Confidence Threshold", 0.0, 1.0, 0.7, help="Minimum confidence for auto-approval")
            st.selectbox("Default Translation Method", ["AI", "Hybrid", "Rule-based"])
            st.number_input("Max Alternatives", value=5, min_value=1, max_value=10)
        
        with col2:
            st.selectbox("LLM Model", ["Claude 3 Sonnet", "Claude 3 Haiku", "GPT-4"])
            st.checkbox("Enable Semantic Search", value=True)
            st.checkbox("Enable Fuzzy Matching", value=True)
    
    with tab3:
        st.subheader("User Management")
        
        # User table
        user_data = {
            'Username': ['admin', 'john.doe', 'jane.smith'],
            'Email': ['admin@propelus.com', 'john@propelus.com', 'jane@propelus.com'],
            'Role': ['Admin', 'Reviewer', 'Viewer'],
            'Status': ['Active', 'Active', 'Inactive']
        }
        
        df_users = pd.DataFrame(user_data)
        st.dataframe(df_users, use_container_width=True, hide_index=True)
        
        if st.button("Add User"):
            st.info("Add user form would appear here")
    
    with tab4:
        st.subheader("System Settings")
        
        col1, col2 = st.columns(2)
        with col1:
            st.selectbox("Environment", ["Development", "Staging", "Production"])
            st.checkbox("Debug Mode", value=False)
            st.checkbox("Enable Monitoring", value=True)
        
        with col2:
            st.text_input("Log Level", value="INFO")
            st.number_input("Session Timeout (minutes)", value=30)
            st.checkbox("Enable Audit Logging", value=True)
        
        if st.button("Save Settings", type="primary"):
            st.success("Settings saved successfully!")

# Main application
def main():
    if not check_auth():
        return
    
    page = render_sidebar()
    
    # Route to appropriate page
    if page == "📊 Dashboard":
        render_dashboard()
    elif page == "🏢 Profession Management":
        render_profession_management()
    elif page == "🔄 Translation Review":
        render_translation_review()
    elif page == "📝 Audit Logs":
        render_audit_logs()
    elif page == "⚙️ Settings":
        render_settings()

if __name__ == "__main__":
    main()
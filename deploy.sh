#!/bin/bash

################################################################################
# OrderCart Deployment Script
# Modular, resumable deployment for all 4 services
# Features:
# - Resumable: Tracks progress, can restart from last successful step
# - Modular: Each step is independent, failures don't affect completed steps
# - Safe: Checks for existing resources before creating duplicates
# - Tracked: Logs all created resources
################################################################################

set -e  # Exit on error (but we'll handle errors gracefully)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# State files
STATE_FILE=".deployment_state"
RESOURCES_FILE=".deployed_resources.txt"

# Initialize state file if doesn't exist
if [ ! -f "$STATE_FILE" ]; then
    echo "STEP_0=pending" > "$STATE_FILE"
fi

# Initialize resources file
if [ ! -f "$RESOURCES_FILE" ]; then
    echo "# OrderCart Deployed Resources - $(date)" > "$RESOURCES_FILE"
    echo "# This file tracks all resources created during deployment" >> "$RESOURCES_FILE"
    echo "" >> "$RESOURCES_FILE"
fi

################################################################################
# Utility Functions
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

update_state() {
    local step=$1
    local status=$2

    # Update or add state
    if grep -q "^${step}=" "$STATE_FILE"; then
        sed -i "s/^${step}=.*/${step}=${status}/" "$STATE_FILE"
    else
        echo "${step}=${status}" >> "$STATE_FILE"
    fi
}

check_state() {
    local step=$1
    local status=$(grep "^${step}=" "$STATE_FILE" 2>/dev/null | cut -d'=' -f2)

    if [ "$status" == "completed" ]; then
        return 0  # Already completed
    else
        return 1  # Not completed
    fi
}

log_resource() {
    local resource_type=$1
    local resource_name=$2
    local resource_url=$3

    echo "[$resource_type] $resource_name" >> "$RESOURCES_FILE"
    if [ -n "$resource_url" ]; then
        echo "    URL: $resource_url" >> "$RESOURCES_FILE"
    fi
    echo "" >> "$RESOURCES_FILE"
}

################################################################################
# Step Functions
################################################################################

step_0_welcome() {
    clear
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║           OrderCart Deployment Script v1.0                    ║"
    echo "║           AI-Powered Order Management System                  ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    log_info "This script will deploy 4 services to Google Cloud Run:"
    echo "  1. Agent 1: Intake & Validation Agent"
    echo "  2. Agent 2: Fulfillment Processor Agent"
    echo "  3. Agent 3: Exception Handler Agent"
    echo "  4. OrderCart Web Application"
    echo ""
    log_info "Deployment is resumable - if interrupted, rerun this script"
    echo ""
}

step_1_collect_config() {
    if check_state "STEP_1"; then
        log_info "Step 1: Configuration already collected, loading..."
        source .deployment_config
        return 0
    fi

    log_info "Step 1: Collecting Configuration"
    echo ""

    # Project ID
    read -p "Enter your Google Cloud Project ID: " PROJECT_ID

    # Google API Key
    read -p "Enter your Google API Key (for Gemma AI): " GOOGLE_API_KEY

    # Gmail credentials
    read -p "Enter your Gmail address (for sending emails): " GMAIL_USER
    read -sp "Enter your Gmail App Password: " GMAIL_APP_PASSWORD
    echo ""

    # Region
    read -p "Enter deployment region (default: us-central1): " REGION
    REGION=${REGION:-us-central1}

    # Save configuration
    cat > .deployment_config << EOF
PROJECT_ID=$PROJECT_ID
GOOGLE_API_KEY=$GOOGLE_API_KEY
GMAIL_USER=$GMAIL_USER
GMAIL_APP_PASSWORD=$GMAIL_APP_PASSWORD
REGION=$REGION
EOF

    log_success "Configuration saved"
    update_state "STEP_1" "completed"
}

step_2_setup_project() {
    if check_state "STEP_2"; then
        log_info "Step 2: Project already configured, skipping..."
        return 0
    fi

    log_info "Step 2: Setting up Google Cloud Project"

    # Set project
    gcloud config set project $PROJECT_ID || {
        log_error "Failed to set project. Please check your Project ID."
        return 1
    }

    log_success "Project configured: $PROJECT_ID"
    update_state "STEP_2" "completed"
    log_resource "PROJECT" "$PROJECT_ID"
}

step_3_enable_apis() {
    if check_state "STEP_3"; then
        log_info "Step 3: APIs already enabled, skipping..."
        return 0
    fi

    log_info "Step 3: Enabling Required APIs (this may take 2-3 minutes)"

    gcloud services enable run.googleapis.com --project=$PROJECT_ID 2>/dev/null || log_warning "Cloud Run API already enabled"
    gcloud services enable firestore.googleapis.com --project=$PROJECT_ID 2>/dev/null || log_warning "Firestore API already enabled"
    gcloud services enable pubsub.googleapis.com --project=$PROJECT_ID 2>/dev/null || log_warning "Pub/Sub API already enabled"
    gcloud services enable cloudbuild.googleapis.com --project=$PROJECT_ID 2>/dev/null || log_warning "Cloud Build API already enabled"

    log_success "All required APIs enabled"
    update_state "STEP_3" "completed"
    log_resource "API" "Cloud Run, Firestore, Pub/Sub, Cloud Build"
}

step_4_create_firestore() {
    if check_state "STEP_4"; then
        log_info "Step 4: Firestore already created, skipping..."
        return 0
    fi

    log_info "Step 4: Creating Firestore Database"

    # Check if database already exists
    if gcloud firestore databases list --project=$PROJECT_ID 2>/dev/null | grep -q "default"; then
        log_warning "Firestore database already exists"
    else
        gcloud firestore databases create --region=$REGION --project=$PROJECT_ID || {
            log_error "Failed to create Firestore database"
            return 1
        }
        log_success "Firestore database created"
    fi

    update_state "STEP_4" "completed"
    log_resource "FIRESTORE" "default" "https://console.cloud.google.com/firestore/data?project=$PROJECT_ID"
}

step_5_create_pubsub() {
    if check_state "STEP_5"; then
        log_info "Step 5: Pub/Sub already configured, skipping..."
        return 0
    fi

    log_info "Step 5: Creating Pub/Sub Topics and Subscriptions"

    # Create topics
    for topic in order-validated order-exception communication-request; do
        if gcloud pubsub topics list --project=$PROJECT_ID | grep -q "$topic"; then
            log_warning "Topic $topic already exists"
        else
            gcloud pubsub topics create $topic --project=$PROJECT_ID
            log_success "Created topic: $topic"
            log_resource "PUBSUB_TOPIC" "$topic"
        fi
    done

    # Create subscriptions
    if gcloud pubsub subscriptions list --project=$PROJECT_ID | grep -q "processor-sub"; then
        log_warning "Subscription processor-sub already exists"
    else
        gcloud pubsub subscriptions create processor-sub --topic=order-validated --project=$PROJECT_ID
        log_success "Created subscription: processor-sub"
        log_resource "PUBSUB_SUB" "processor-sub"
    fi

    if gcloud pubsub subscriptions list --project=$PROJECT_ID | grep -q "exception-sub"; then
        log_warning "Subscription exception-sub already exists"
    else
        gcloud pubsub subscriptions create exception-sub --topic=order-exception --project=$PROJECT_ID
        log_success "Created subscription: exception-sub"
        log_resource "PUBSUB_SUB" "exception-sub"
    fi

    if gcloud pubsub subscriptions list --project=$PROJECT_ID | grep -q "communication-sub"; then
        log_warning "Subscription communication-sub already exists"
    else
        gcloud pubsub subscriptions create communication-sub --topic=communication-request --project=$PROJECT_ID
        log_success "Created subscription: communication-sub"
        log_resource "PUBSUB_SUB" "communication-sub"
    fi

    update_state "STEP_5" "completed"
}

step_6_deploy_agent1() {
    if check_state "STEP_6"; then
        log_info "Step 6: Agent 1 already deployed, skipping..."
        # Load URL from resources file
        AGENT1_URL=$(grep -A 1 "\[CLOUD_RUN\] agent-intake-validator" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
        return 0
    fi

    log_info "Step 6: Deploying Agent 1 (Intake & Validation)"
    cd agent-intake-validator

    gcloud run deploy agent-intake-validator \
        --source . \
        --region $REGION \
        --platform managed \
        --allow-unauthenticated \
        --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID,GOOGLE_API_KEY=$GOOGLE_API_KEY" \
        --memory 512Mi \
        --timeout 120 \
        --project=$PROJECT_ID || {
        log_error "Failed to deploy Agent 1"
        cd ..
        return 1
    }

    AGENT1_URL=$(gcloud run services describe agent-intake-validator --region=$REGION --project=$PROJECT_ID --format='value(status.url)')

    cd ..
    log_success "Agent 1 deployed: $AGENT1_URL"
    update_state "STEP_6" "completed"
    log_resource "CLOUD_RUN" "agent-intake-validator" "$AGENT1_URL"
}

step_7_deploy_agent2() {
    if check_state "STEP_7"; then
        log_info "Step 7: Agent 2 already deployed, skipping..."
        AGENT2_URL=$(grep -A 1 "\[CLOUD_RUN\] agent-fulfillment-processor" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
        return 0
    fi

    log_info "Step 7: Deploying Agent 2 (Fulfillment Processor)"
    cd agent-fulfillment-processor

    gcloud run deploy agent-fulfillment-processor \
        --source . \
        --region $REGION \
        --platform managed \
        --allow-unauthenticated \
        --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID,GOOGLE_API_KEY=$GOOGLE_API_KEY" \
        --memory 512Mi \
        --timeout 120 \
        --project=$PROJECT_ID || {
        log_error "Failed to deploy Agent 2"
        cd ..
        return 1
    }

    AGENT2_URL=$(gcloud run services describe agent-fulfillment-processor --region=$REGION --project=$PROJECT_ID --format='value(status.url)')

    cd ..
    log_success "Agent 2 deployed: $AGENT2_URL"
    update_state "STEP_7" "completed"
    log_resource "CLOUD_RUN" "agent-fulfillment-processor" "$AGENT2_URL"
}

step_8_deploy_agent3() {
    if check_state "STEP_8"; then
        log_info "Step 8: Agent 3 already deployed, skipping..."
        AGENT3_URL=$(grep -A 1 "\[CLOUD_RUN\] agent-exception-handler" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
        return 0
    fi

    log_info "Step 8: Deploying Agent 3 (Exception Handler)"
    cd agent-exception-handler

    gcloud run deploy agent-exception-handler \
        --source . \
        --region $REGION \
        --platform managed \
        --allow-unauthenticated \
        --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID,GOOGLE_API_KEY=$GOOGLE_API_KEY,GMAIL_USER=$GMAIL_USER,GMAIL_APP_PASSWORD=$GMAIL_APP_PASSWORD" \
        --memory 512Mi \
        --timeout 120 \
        --project=$PROJECT_ID || {
        log_error "Failed to deploy Agent 3"
        cd ..
        return 1
    }

    AGENT3_URL=$(gcloud run services describe agent-exception-handler --region=$REGION --project=$PROJECT_ID --format='value(status.url)')

    cd ..
    log_success "Agent 3 deployed: $AGENT3_URL"
    update_state "STEP_8" "completed"
    log_resource "CLOUD_RUN" "agent-exception-handler" "$AGENT3_URL"
}

step_9_deploy_webapp() {
    if check_state "STEP_9"; then
        log_info "Step 9: Web App already deployed, skipping..."
        WEBAPP_URL=$(grep -A 1 "\[CLOUD_RUN\] ordercart-webapp" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
        return 0
    fi

    log_info "Step 9: Deploying OrderCart Web Application"

    # Load agent URLs if not already loaded
    if [ -z "$AGENT1_URL" ]; then
        AGENT1_URL=$(grep -A 1 "\[CLOUD_RUN\] agent-intake-validator" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
    fi
    if [ -z "$AGENT2_URL" ]; then
        AGENT2_URL=$(grep -A 1 "\[CLOUD_RUN\] agent-fulfillment-processor" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
    fi
    if [ -z "$AGENT3_URL" ]; then
        AGENT3_URL=$(grep -A 1 "\[CLOUD_RUN\] agent-exception-handler" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
    fi

    cd ordercart-webapp

    gcloud run deploy ordercart-webapp \
        --source . \
        --region $REGION \
        --platform managed \
        --allow-unauthenticated \
        --set-env-vars="GOOGLE_CLOUD_PROJECT=$PROJECT_ID,AGENT_INTAKE_URL=$AGENT1_URL,AGENT_PROCESSOR_URL=$AGENT2_URL,AGENT_EXCEPTION_URL=$AGENT3_URL" \
        --memory 512Mi \
        --timeout 120 \
        --project=$PROJECT_ID || {
        log_error "Failed to deploy Web App"
        cd ..
        return 1
    }

    WEBAPP_URL=$(gcloud run services describe ordercart-webapp --region=$REGION --project=$PROJECT_ID --format='value(status.url)')

    cd ..
    log_success "Web App deployed: $WEBAPP_URL"
    update_state "STEP_9" "completed"
    log_resource "CLOUD_RUN" "ordercart-webapp" "$WEBAPP_URL"
}

step_10_summary() {
    log_info "Step 10: Deployment Summary"
    echo ""

    # Load URLs
    AGENT1_URL=$(grep -A 1 "\[CLOUD_RUN\] agent-intake-validator" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
    AGENT2_URL=$(grep -A 1 "\[CLOUD_RUN\] agent-fulfillment-processor" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
    AGENT3_URL=$(grep -A 1 "\[CLOUD_RUN\] agent-exception-handler" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')
    WEBAPP_URL=$(grep -A 1 "\[CLOUD_RUN\] ordercart-webapp" "$RESOURCES_FILE" | grep "URL:" | awk '{print $2}')

    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}║              DEPLOYMENT COMPLETED SUCCESSFULLY!               ║${NC}"
    echo -e "${GREEN}║                                                               ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Service URLs:${NC}"
    echo ""
    echo -e "  ${YELLOW}Agent 1 (Intake):${NC}"
    echo -e "    $AGENT1_URL"
    echo ""
    echo -e "  ${YELLOW}Agent 2 (Processor):${NC}"
    echo -e "    $AGENT2_URL"
    echo ""
    echo -e "  ${YELLOW}Agent 3 (Exception):${NC}"
    echo -e "    $AGENT3_URL"
    echo ""
    echo -e "  ${YELLOW}Web Application:${NC}"
    echo -e "    ${GREEN}$WEBAPP_URL${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo "  1. Open the Web App URL in your browser"
    echo "  2. Try submitting a test order"
    echo "  3. Explore the dashboard and features"
    echo ""
    echo -e "${BLUE}Resources:${NC}"
    echo "  - All deployed resources logged in: .deployed_resources.txt"
    echo "  - Deployment state saved in: .deployment_state"
    echo ""
    log_info "To view all resources, run: cat .deployed_resources.txt"
    echo ""
}

################################################################################
# Main Execution
################################################################################

main() {
    step_0_welcome

    # Load config if exists
    if [ -f .deployment_config ]; then
        source .deployment_config
    fi

    # Execute steps
    step_1_collect_config || exit 1
    sleep 1

    source .deployment_config  # Reload config

    step_2_setup_project || exit 1
    sleep 1

    step_3_enable_apis || exit 1
    sleep 2

    step_4_create_firestore || exit 1
    sleep 1

    step_5_create_pubsub || exit 1
    sleep 1

    step_6_deploy_agent1 || exit 1
    sleep 1

    step_7_deploy_agent2 || exit 1
    sleep 1

    step_8_deploy_agent3 || exit 1
    sleep 1

    step_9_deploy_webapp || exit 1
    sleep 1

    step_10_summary

    # Mark overall deployment as complete
    update_state "DEPLOYMENT" "completed"
}

# Run main function
main "$@"

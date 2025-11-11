#!/bin/bash

################################################################################
# OrderCart Update Script
# Redeploys only changed services without recreating infrastructure
################################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}OrderCart Service Update Script${NC}"
echo ""

# Load existing config
if [ ! -f .deployment_config ]; then
    echo -e "${YELLOW}No deployment config found. Run ./deploy.sh first.${NC}"
    exit 1
fi

source .deployment_config

echo "Project: $PROJECT_ID"
echo "Region: $REGION"
echo ""
echo "Which service(s) do you want to update?"
echo ""
echo "  1) Agent 1: Intake & Validation"
echo "  2) Agent 2: Fulfillment Processor"
echo "  3) Agent 3: Exception Handler"
echo "  4) Web Application"
echo "  5) All Services"
echo ""
read -p "Enter choice (1-5): " choice

update_agent1() {
    echo -e "${BLUE}Updating Agent 1...${NC}"
    cd agent-intake-validator
    gcloud run deploy agent-intake-validator \
        --source . \
        --region $REGION \
        --project $PROJECT_ID \
        --quiet
    cd ..
    echo -e "${GREEN}✓ Agent 1 updated${NC}"
}

update_agent2() {
    echo -e "${BLUE}Updating Agent 2...${NC}"
    cd agent-fulfillment-processor
    gcloud run deploy agent-fulfillment-processor \
        --source . \
        --region $REGION \
        --project $PROJECT_ID \
        --quiet
    cd ..
    echo -e "${GREEN}✓ Agent 2 updated${NC}"
}

update_agent3() {
    echo -e "${BLUE}Updating Agent 3...${NC}"
    cd agent-exception-handler
    gcloud run deploy agent-exception-handler \
        --source . \
        --region $REGION \
        --project $PROJECT_ID \
        --quiet
    cd ..
    echo -e "${GREEN}✓ Agent 3 updated${NC}"
}

update_webapp() {
    echo -e "${BLUE}Updating Web App...${NC}"
    cd ordercart-webapp
    gcloud run deploy ordercart-webapp \
        --source . \
        --region $REGION \
        --project $PROJECT_ID \
        --quiet
    cd ..
    echo -e "${GREEN}✓ Web App updated${NC}"
}

case $choice in
    1) update_agent1 ;;
    2) update_agent2 ;;
    3) update_agent3 ;;
    4) update_webapp ;;
    5)
        update_agent1
        update_agent2
        update_agent3
        update_webapp
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Update complete!${NC}"
echo ""
echo "Your services are now running the latest code."
echo "No data was lost, URLs remain the same."

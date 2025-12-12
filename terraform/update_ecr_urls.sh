#!/bin/bash

# Script to automatically update Kubernetes deployment files with ECR repository URLs from Terraform
# This ensures deployments always use the correct, automated ECR URLs

set -e

echo "=========================================="
echo "ECR URL Automation Script"
echo "=========================================="

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Paths
TERRAFORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GITOPS_DIR="$(cd "$TERRAFORM_DIR/../../salon-gitops" && pwd)"
STAGING_DIR="$GITOPS_DIR/staging"

echo -e "${YELLOW}Terraform Directory:${NC} $TERRAFORM_DIR"
echo -e "${YELLOW}GitOps Directory:${NC} $GITOPS_DIR"
echo ""

# Check if terraform is initialized
if [ ! -d "$TERRAFORM_DIR/.terraform" ]; then
    echo -e "${RED}ERROR: Terraform not initialized!${NC}"
    echo "Please run 'terraform init' first."
    exit 1
fi

echo -e "${GREEN}Step 1: Extracting ECR URLs from Terraform...${NC}"

# Get ECR repository URLs from Terraform output
cd "$TERRAFORM_DIR"
ECR_URLS=$(terraform output -json ecr_repository_urls 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$ECR_URLS" ] || [ "$ECR_URLS" = "{}" ] || [ "$ECR_URLS" = "null" ]; then
    echo -e "${YELLOW}WARNING: No ECR repositories found in Terraform state${NC}"
    echo "This is normal if ECR repos haven't been created yet."
    echo "The script will run after ECR repos are created."
    echo ""
    echo -e "${GREEN}Skipping deployment file updates (nothing to update yet)${NC}"
    exit 0
fi

# Parse JSON and create associative array
declare -A ECR_MAP
while IFS="=" read -r key value; do
    # Remove quotes and whitespace
    key=$(echo "$key" | tr -d '"' | xargs)
    value=$(echo "$value" | tr -d '",' | xargs)
    if [ -n "$key" ] && [ -n "$value" ]; then
        ECR_MAP["$key"]="$value"
    fi
done < <(echo "$ECR_URLS" | jq -r 'to_entries|map("\(.key)=\(.value)")|.[]' 2>/dev/null)

if [ ${#ECR_MAP[@]} -eq 0 ]; then
    echo -e "${RED}ERROR: No ECR repositories found${NC}"
    exit 1
fi

echo -e "${GREEN}Found ${#ECR_MAP[@]} ECR repositories:${NC}"
for service in "${!ECR_MAP[@]}"; do
    echo "  - $service: ${ECR_MAP[$service]}"
done
echo ""

# Function to update deployment file
update_deployment() {
    local service=$1
    local ecr_url=$2
    local deployment_file="$STAGING_DIR/$service/deployment.yaml"
    
    if [ ! -f "$deployment_file" ]; then
        echo -e "${YELLOW}  ⚠ Deployment file not found: $deployment_file${NC}"
        return 1
    fi
    
    # Check if file contains an image line
    if ! grep -q "image:" "$deployment_file"; then
        echo -e "${YELLOW}  ⚠ No 'image:' field found in $deployment_file${NC}"
        return 1
    fi
    
    # Get current image
    CURRENT_IMAGE=$(grep "image:" "$deployment_file" | head -1 | awk '{print $2}')
    
    # Extract current tag (default to :latest if not found)
    if [[ "$CURRENT_IMAGE" == *":"* ]]; then
        CURRENT_TAG=$(echo "$CURRENT_IMAGE" | awk -F: '{print $2}')
    else
        CURRENT_TAG="latest"
    fi
    
    # New image URL with preserved tag
    NEW_IMAGE="${ecr_url}:${CURRENT_TAG}"
    
    # Update the deployment file
    sed -i.bak "s|image:.*|image: ${NEW_IMAGE}|g" "$deployment_file"
    
    echo -e "${GREEN}  ✓ Updated: $service${NC}"
    echo "    Old: $CURRENT_IMAGE"
    echo "    New: $NEW_IMAGE"
    
    # Remove backup file
    rm -f "$deployment_file.bak"
    
    return 0
}

echo -e "${GREEN}Step 2: Updating deployment files...${NC}"
echo ""

UPDATED_COUNT=0
SKIPPED_COUNT=0

# Update each service deployment
for service in "${!ECR_MAP[@]}"; do
    if update_deployment "$service" "${ECR_MAP[$service]}"; then
        ((UPDATED_COUNT++))
    else
        ((SKIPPED_COUNT++))
    fi
done

echo ""
echo "=========================================="
echo -e "${GREEN}Summary:${NC}"
echo "  Updated: $UPDATED_COUNT"
echo "  Skipped: $SKIPPED_COUNT"
echo "=========================================="
echo ""

if [ $UPDATED_COUNT -gt 0 ]; then
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Review the changes:"
    echo "     cd $GITOPS_DIR"
    echo "     git diff"
    echo ""
    echo "  2. Commit and push if changes look good:"
    echo "     git add staging/"
    echo "     git commit -m 'Update ECR URLs from Terraform automation'"
    echo "     git push"
    echo ""
    echo "  3. ArgoCD will automatically sync the changes!"
fi

echo -e "${GREEN}Done!${NC}"

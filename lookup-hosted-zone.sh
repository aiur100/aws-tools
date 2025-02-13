#!/bin/bash

# Function to display usage instructions
usage() {
    echo "Usage: $0 --domain <domain-name> [--profile <aws-profile>]"
    echo "Example: $0 --domain example.com --profile myprofile"
    exit 1
}

# Function to validate domain name format
validate_domain() {
    local domain=$1
    if [[ ! $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)*\.[a-zA-Z]{2,}$ ]]; then
        echo "Error: Invalid domain name format"
        exit 1
    fi
}

# Parse command line arguments
DOMAIN=""
PROFILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

# Check if domain is provided
if [ -z "$DOMAIN" ]; then
    echo "Error: Domain name must be provided"
    usage
fi

# Validate domain name
validate_domain "$DOMAIN"

# Prepare AWS CLI command
AWS_CMD="aws"
if [ ! -z "$PROFILE" ]; then
    AWS_CMD="$AWS_CMD --profile $PROFILE"
fi

# Look up hosted zone
echo "Looking up hosted zone for domain: $DOMAIN"
HOSTED_ZONE=$($AWS_CMD route53 list-hosted-zones-by-name \
    --dns-name "$DOMAIN" \
    --max-items 1 \
    --query 'HostedZones[0].[Id,Name]' \
    --output text)

# Check if hosted zone was found
if [ $? -eq 0 ] && [ ! -z "$HOSTED_ZONE" ]; then
    ZONE_ID=$(echo "$HOSTED_ZONE" | cut -f1)
    ZONE_NAME=$(echo "$HOSTED_ZONE" | cut -f2)
    
    # Remove trailing dot from zone name
    ZONE_NAME=${ZONE_NAME%?}
    
    # Extract just the ID without the /hostedzone/ prefix
    ZONE_ID=${ZONE_ID#/hostedzone/}
    
    echo "Found hosted zone:"
    echo "Zone ID: $ZONE_ID"
    echo "Zone Name: $ZONE_NAME"
else
    echo "Error: No hosted zone found for domain $DOMAIN"
    exit 1
fi

#!/bin/bash

# Function to display usage instructions
usage() {
    echo "Usage: $0 (--domain <domain-name> | --operation-id <operation-id>) [--profile <aws-profile>]"
    echo "Example: $0 --domain example.com --profile myprofile"
    echo "         $0 --operation-id abc123-def456 --profile myprofile"
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
OPERATION_ID=""
PROFILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --operation-id)
            OPERATION_ID="$2"
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

# Check if either domain or operation ID is provided
if [ -z "$DOMAIN" ] && [ -z "$OPERATION_ID" ]; then
    echo "Error: Either domain name or operation ID must be provided"
    usage
fi

if [ ! -z "$DOMAIN" ] && [ ! -z "$OPERATION_ID" ]; then
    echo "Error: Please provide either domain name or operation ID, not both"
    usage
fi

# Validate domain name if provided
if [ ! -z "$DOMAIN" ]; then
    validate_domain "$DOMAIN"
fi

# Prepare AWS CLI command
AWS_CMD="aws route53domains"
if [ ! -z "$PROFILE" ]; then
    AWS_CMD="$AWS_CMD --profile $PROFILE"
fi

# Check status based on input type
if [ ! -z "$DOMAIN" ]; then
    echo "Checking status for domain: $DOMAIN"
    $AWS_CMD get-domain-detail --domain-name "$DOMAIN"
else
    echo "Checking status for operation ID: $OPERATION_ID"
    $AWS_CMD get-operation-detail --operation-id "$OPERATION_ID"
fi

# Check the command status
if [ $? -eq 0 ]; then
    echo "Status check completed successfully"
else
    echo "Error: Failed to retrieve status"
    echo "Please check your AWS credentials and try again"
    exit 1
fi

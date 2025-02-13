#!/bin/bash

# Function to display usage instructions
usage() {
    echo "Usage: $0 <domain-name> [--profile <aws-profile>]"
    echo "Example: $0 example.com --profile myprofile"
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

# Function to check if contact details file exists
check_contact_details() {
    if [ ! -f "contact-details.json" ]; then
        echo "Error: contact-details.json not found"
        echo "Please create contact-details.json with your domain registration information"
        exit 1
    fi
}

# Function to validate JSON format
validate_json() {
    if ! jq empty contact-details.json 2>/dev/null; then
        echo "Error: Invalid JSON format in contact-details.json"
        exit 1
    fi
}

# Parse command line arguments
DOMAIN=""
PROFILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        *)
            if [ -z "$DOMAIN" ]; then
                DOMAIN="$1"
                shift
            else
                usage
            fi
            ;;
    esac
done

# Check if domain name is provided
if [ -z "$DOMAIN" ]; then
    usage
fi

# Validate domain name format
validate_domain "$DOMAIN"

# Check for contact details file
check_contact_details

# Validate JSON format
validate_json

# Prepare AWS CLI command
AWS_CMD="aws route53domains register-domain"
if [ ! -z "$PROFILE" ]; then
    AWS_CMD="$AWS_CMD --profile $PROFILE"
fi

# Read contact details from JSON file
CONTACT_DETAILS=$(cat contact-details.json)

# Register domain
echo "Attempting to register domain: $DOMAIN"
$AWS_CMD \
    --domain-name "$DOMAIN" \
    --duration-in-years 1 \
    --auto-renew \
    --admin-contact "$CONTACT_DETAILS" \
    --registrant-contact "$CONTACT_DETAILS" \
    --tech-contact "$CONTACT_DETAILS" \
    --privacy-protect-admin \
    --privacy-protect-registrant \
    --privacy-protect-tech

# Check the command status
if [ $? -eq 0 ]; then
    echo "Domain registration process initiated successfully for $DOMAIN"
    echo "Please check AWS Console for registration status"
    echo "You may receive confirmation emails for domain ownership verification"
else
    echo "Error: Domain registration failed"
    echo "Please check your AWS credentials and try again"
    exit 1
fi

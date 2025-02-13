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

# Check if certificate already exists
echo "Checking for existing certificates for domain: $DOMAIN"
EXISTING_CERT=$($AWS_CMD acm list-certificates --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text)

if [ ! -z "$EXISTING_CERT" ]; then
    echo "Certificate already exists for $DOMAIN"
    echo "Certificate ARN: $EXISTING_CERT"
    exit 0
fi

# Request new certificate
echo "Requesting new certificate for domain: $DOMAIN"
CERT_ARN=$($AWS_CMD acm request-certificate \
    --domain-name "$DOMAIN" \
    --validation-method DNS \
    --query 'CertificateArn' \
    --output text)

# Check if certificate request was successful
if [ $? -eq 0 ] && [ ! -z "$CERT_ARN" ]; then
    echo "Certificate requested successfully"
    echo "Certificate ARN: $CERT_ARN"
    echo "Please create the required DNS validation records to complete the certificate issuance"
    
    # Get validation records
    echo "Retrieving DNS validation records..."
    $AWS_CMD acm describe-certificate \
        --certificate-arn "$CERT_ARN" \
        --query 'Certificate.DomainValidationOptions[].ResourceRecord'
else
    echo "Error: Failed to request certificate"
    echo "Please check your AWS credentials and try again"
    exit 1
fi

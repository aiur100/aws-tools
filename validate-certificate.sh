#!/bin/bash

# Function to display usage instructions
usage() {
    echo "Usage: $0 (--arn <certificate-arn> | --domain <domain-name>) [--profile <aws-profile>]"
    echo "Example: $0 --arn arn:aws:acm:region:account:certificate/12345678-1234-1234-1234-123456789012"
    echo "         $0 --domain example.com --profile myprofile"
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

# Function to validate ARN format
validate_arn() {
    local arn=$1
    if [[ ! $arn =~ ^arn:aws:acm:[^:]+:[0-9]+:certificate/[a-zA-Z0-9-]+$ ]]; then
        echo "Error: Invalid certificate ARN format"
        exit 1
    fi
}

# Parse command line arguments
CERT_ARN=""
DOMAIN=""
PROFILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --arn)
            CERT_ARN="$2"
            shift 2
            ;;
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

# Check if either ARN or domain is provided
if [ -z "$CERT_ARN" ] && [ -z "$DOMAIN" ]; then
    echo "Error: Either certificate ARN or domain name must be provided"
    usage
fi

if [ ! -z "$CERT_ARN" ] && [ ! -z "$DOMAIN" ]; then
    echo "Error: Please provide either certificate ARN or domain name, not both"
    usage
fi

# Prepare AWS CLI command
AWS_CMD="aws"
if [ ! -z "$PROFILE" ]; then
    AWS_CMD="$AWS_CMD --profile $PROFILE"
fi

# If domain is provided, look up the certificate ARN
if [ ! -z "$DOMAIN" ]; then
    validate_domain "$DOMAIN"
    echo "Looking up certificate ARN for domain: $DOMAIN"
    CERT_ARN=$($AWS_CMD acm list-certificates --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn" --output text)
    
    if [ -z "$CERT_ARN" ]; then
        echo "Error: No certificate found for domain $DOMAIN"
        exit 1
    fi
    echo "Found certificate ARN: $CERT_ARN"
else
    validate_arn "$CERT_ARN"
fi

# Get certificate details and validation records
echo "Retrieving certificate validation records..."
CERT_DETAILS=$($AWS_CMD acm describe-certificate --certificate-arn "$CERT_ARN" --query 'Certificate.DomainValidationOptions[0]' --output json)

if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve certificate details"
    exit 1
fi

# Extract domain and validation records
DOMAIN_NAME=$(echo "$CERT_DETAILS" | jq -r '.DomainName')
RECORD_NAME=$(echo "$CERT_DETAILS" | jq -r '.ResourceRecord.Name')
RECORD_VALUE=$(echo "$CERT_DETAILS" | jq -r '.ResourceRecord.Value')
RECORD_TYPE=$(echo "$CERT_DETAILS" | jq -r '.ResourceRecord.Type')

if [ -z "$RECORD_NAME" ] || [ -z "$RECORD_VALUE" ] || [ -z "$RECORD_TYPE" ]; then
    echo "Error: Failed to extract validation records from certificate"
    exit 1
fi

# Look up hosted zone ID
echo "Looking up hosted zone for domain: $DOMAIN_NAME"
HOSTED_ZONE=$($AWS_CMD route53 list-hosted-zones-by-name \
    --dns-name "$DOMAIN_NAME" \
    --max-items 1 \
    --query 'HostedZones[0].Id' \
    --output text)

if [ -z "$HOSTED_ZONE" ]; then
    echo "Error: No hosted zone found for domain $DOMAIN_NAME"
    exit 1
fi

# Create JSON for the Route 53 change
CHANGE_JSON=$(cat << EOF
{
    "Changes": [
        {
            "Action": "UPSERT",
            "ResourceRecordSet": {
                "Name": "$RECORD_NAME",
                "Type": "$RECORD_TYPE",
                "TTL": 300,
                "ResourceRecords": [
                    {
                        "Value": "$RECORD_VALUE"
                    }
                ]
            }
        }
    ]
}
EOF
)

# Create temporary file for the change batch
TMPFILE=$(mktemp)
echo "$CHANGE_JSON" > "$TMPFILE"

# Apply the DNS change
echo "Adding validation record to Route 53..."
$AWS_CMD route53 change-resource-record-sets \
    --hosted-zone-id "$HOSTED_ZONE" \
    --change-batch "file://$TMPFILE"

RESULT=$?
rm "$TMPFILE"

if [ $RESULT -eq 0 ]; then
    echo "Successfully added validation record to Route 53"
    echo "Domain: $DOMAIN_NAME"
    echo "Record Name: $RECORD_NAME"
    echo "Record Type: $RECORD_TYPE"
    echo "Record Value: $RECORD_VALUE"
    echo "Certificate validation is in progress. This may take up to 30 minutes to complete."
else
    echo "Error: Failed to add validation record to Route 53"
    exit 1
fi

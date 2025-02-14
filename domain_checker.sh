#!/bin/bash

# Parse command line arguments
PROFILE=""
CSV_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        *)
            CSV_FILE="$1"
            shift
            ;;
    esac
done

if [ -z "$CSV_FILE" ]; then
    echo "Usage: $0 domains.csv [--profile <aws-profile>]"
    exit 1
fi

TEMP_FILE="${CSV_FILE}.tmp"

# Set profile option if specified
PROFILE_OPT=""
if [ -n "$PROFILE" ]; then
    PROFILE_OPT="--profile $PROFILE"
fi

# Check if aws cli is installed
if ! command -v aws &> /dev/null; then
    echo "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity $PROFILE_OPT &> /dev/null; then
    echo "AWS credentials are not properly configured. Please run 'aws configure' first."
    exit 1
fi

# Check if the CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "CSV file not found: $CSV_FILE"
    exit 1
fi

# Set AWS_DEFAULT_REGION if not already set
export AWS_DEFAULT_REGION=us-east-1

echo "Starting domain availability check..."
echo "----------------------------------------"

# Create header in temp file
head -n 1 "$CSV_FILE" > "$TEMP_FILE"

# Process each line
tail -n +2 "$CSV_FILE" | while IFS=, read -r domain checked available; do
    # Remove quotes and whitespace
    domain=$(echo "$domain" | tr -d '"' | tr -d ' ')
    checked=$(echo "$checked" | tr -d '"' | tr -d ' ' | tr -d '\r')
    
    if [ "$checked" = "true" ]; then
        echo "Skipping $domain (already checked)"
        echo "$domain,true,$available" >> "$TEMP_FILE"
        continue
    fi
    
    echo -n "Checking $domain... "
    
    # Check domain availability using AWS CLI
    availability=$(aws $PROFILE_OPT route53domains check-domain-availability \
        --domain-name "$domain" \
        --query 'Availability' \
        --output text 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo "$availability"
        is_available="false"
        if [ "$availability" = "AVAILABLE" ]; then
            is_available="true"
        fi
        echo "$domain,true,$is_available" >> "$TEMP_FILE"
    else
        echo "ERROR: Failed to check domain"
        echo "$domain,false," >> "$TEMP_FILE"
    fi

    # Add a small delay to avoid rate limiting
    sleep 1
done

# Replace original file with updated one
mv "$TEMP_FILE" "$CSV_FILE"

echo "----------------------------------------"
echo "Domain check complete!"
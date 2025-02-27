#!/bin/bash

# Constants
EMAIL_FILE="ses-emails.json"

# Function definitions
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --create-identity <email>    Create a new SES email identity"
    echo "  --verify-identity <email>    Verify a SES email identity"
    echo "  --list-identities            List all SES email identities"
    echo "  --setup-test-inbox           Create and verify a test inbox for receiving emails"
    echo "  --profile <aws-profile>      AWS profile to use (default: default)"
    echo ""
    echo "Examples:"
    echo "  $0 --create-identity no-reply@example.com"
    echo "  $0 --verify-identity test@example.com"
    echo "  $0 --list-identities"
    echo "  $0 --setup-test-inbox test@example.com"
    echo "  $0 --create-identity no-reply@example.com --profile myprofile"
}

validate_email() {
    local email=$1
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "Error: Invalid email format: $email"
        exit 1
    fi
}

create_identity() {
    local email=$1
    
    echo "Creating SES identity for $email..."
    $AWS_CMD ses create-email-identity --email-identity "$email"
    
    if [ $? -eq 0 ]; then
        echo "Identity created successfully. Verification email sent to $email."
        # Save to tracking file
        if [ ! -f "$EMAIL_FILE" ]; then
            echo '{"emails":[]}' > "$EMAIL_FILE"
        fi
        
        local temp_file=$(mktemp)
        jq ".emails += [{\"email\": \"$email\", \"created\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"verified\": false}]" "$EMAIL_FILE" > "$temp_file"
        mv "$temp_file" "$EMAIL_FILE"
    else
        echo "Failed to create identity for $email"
        exit 1
    fi
}

verify_identity() {
    local email=$1
    
    echo "Checking verification status for $email..."
    local result=$($AWS_CMD ses get-email-identity --email-identity "$email" --query 'VerificationStatus' --output text)
    
    if [ "$result" == "Success" ]; then
        echo "Email $email is verified"
        
        # Update tracking file
        if [ -f "$EMAIL_FILE" ]; then
            local temp_file=$(mktemp)
            jq ".emails = .emails | map(if .email == \"$email\" then .verified = true else . end)" "$EMAIL_FILE" > "$temp_file"
            mv "$temp_file" "$EMAIL_FILE"
        fi
    else
        echo "Email $email is not verified yet (status: $result)"
    fi
}

list_identities() {
    echo "Listing all SES email identities..."
    local identities=$($AWS_CMD ses list-email-identities --output json)
    
    if [ $? -eq 0 ]; then
        echo "SES Email Identities:"
        echo "---------------------"
        echo "$identities" | jq -r '.EmailIdentities[] | "\(.IdentityName) - \(.VerificationStatus)"'
    else
        echo "Failed to list identities"
        exit 1
    fi
}

setup_test_inbox() {
    local email=$1
    
    echo "Setting up test inbox for $email..."
    
    # Create identity
    $AWS_CMD ses create-email-identity --email-identity "$email"
    
    if [ $? -eq 0 ]; then
        echo "Test inbox identity created. Verification email sent to $email."
        echo "Please check your inbox and verify the email address."
        echo "After verification, you can set up a rule set to handle incoming email."
        
        # Save to tracking file
        if [ ! -f "$EMAIL_FILE" ]; then
            echo '{"emails":[]}' > "$EMAIL_FILE"
        fi
        
        local temp_file=$(mktemp)
        jq ".emails += [{\"email\": \"$email\", \"created\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"verified\": false, \"type\": \"test_inbox\"}]" "$EMAIL_FILE" > "$temp_file"
        mv "$temp_file" "$EMAIL_FILE"
    else
        echo "Failed to set up test inbox for $email"
        exit 1
    fi
}

check_prerequisites() {
    command -v aws >/dev/null 2>&1 || { echo "Error: AWS CLI not installed"; exit 1; }
    command -v jq >/dev/null 2>&1 || { echo "Error: jq not installed"; exit 1; }
}

# Main script
check_prerequisites

# Default values
PROFILE=""
ACTION=""
EMAIL=""

# Process command-line arguments
while [ "$1" != "" ]; do
    case $1 in
        --create-identity )      shift
                                 ACTION="create"
                                 EMAIL=$1
                                 ;;
        --verify-identity )      shift
                                 ACTION="verify"
                                 EMAIL=$1
                                 ;;
        --list-identities )      ACTION="list"
                                 ;;
        --setup-test-inbox )     shift
                                 ACTION="setup-test"
                                 EMAIL=$1
                                 ;;
        --profile )              shift
                                 PROFILE=$1
                                 ;;
        -h | --help )            usage
                                 exit
                                 ;;
        * )                      usage
                                 exit 1
    esac
    shift
done

# AWS CLI command with profile if provided
AWS_CMD="aws"
if [ ! -z "$PROFILE" ]; then 
    AWS_CMD="$AWS_CMD --profile $PROFILE"
fi

# Execute action
case $ACTION in
    create)
        if [ -z "$EMAIL" ]; then
            echo "Error: Email address required for identity creation"
            usage
            exit 1
        fi
        validate_email "$EMAIL"
        create_identity "$EMAIL"
        ;;
    verify)
        if [ -z "$EMAIL" ]; then
            echo "Error: Email address required for verification check"
            usage
            exit 1
        fi
        validate_email "$EMAIL"
        verify_identity "$EMAIL"
        ;;
    list)
        list_identities
        ;;
    setup-test)
        if [ -z "$EMAIL" ]; then
            echo "Error: Email address required for test inbox setup"
            usage
            exit 1
        fi
        validate_email "$EMAIL"
        setup_test_inbox "$EMAIL"
        ;;
    *)
        echo "Error: No action specified"
        usage
        exit 1
        ;;
esac

exit 0
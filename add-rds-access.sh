#!/bin/bash

# Default values
AWS_PROFILE="default"
POSTGRES_PORT=5432
IP_ADDRESS=""

# Function to display usage information
usage() {
    echo "Usage: $0 [--profile <aws-profile>] [--ip-address <ip-address>]"
    echo
    echo "Options:"
    echo "  --profile     AWS profile to use (default: default)"
    echo "  --ip-address  Specific IP address to add (default: auto-detect)"
    echo
    echo "Example:"
    echo "  $0 --profile myprofile"
    echo "  $0 --ip-address 192.168.1.1"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        --ip-address)
            IP_ADDRESS="$2"
            shift 2
            ;;
        --help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Get current IP address if not provided
if [ -z "$IP_ADDRESS" ]; then
    IP_ADDRESS=$(curl -s https://checkip.amazonaws.com)
    if [ -z "$IP_ADDRESS" ]; then
        echo "Error: Could not determine current IP address"
        exit 1
    fi
    echo "Using auto-detected IP address: $IP_ADDRESS"
else
    echo "Using provided IP address: $IP_ADDRESS"
fi

# Get list of RDS instances
echo "Fetching RDS instances..."
RDS_INSTANCES=$(aws rds describe-db-instances --profile "$AWS_PROFILE" --query 'DBInstances[*].[DBInstanceIdentifier,Engine,DBInstanceStatus]' --output json)
if [ -z "$RDS_INSTANCES" ] || [ "$RDS_INSTANCES" == "[]" ]; then
    echo "No RDS instances found in account"
    exit 1
fi

# Display instances and prompt for selection
echo
echo "Available RDS instances:"
echo "----------------------"
instance_count=$(echo "$RDS_INSTANCES" | jq length)

for ((i=0; i<instance_count; i++)); do
    instance_id=$(echo "$RDS_INSTANCES" | jq -r ".[$i][0]")
    engine=$(echo "$RDS_INSTANCES" | jq -r ".[$i][1]")
    status=$(echo "$RDS_INSTANCES" | jq -r ".[$i][2]")
    echo "[$((i+1))] $instance_id ($engine) - Status: $status"
done

echo
while true; do
    read -p "Select an RDS instance (1-$instance_count): " selection
    if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "$instance_count" ]; then
        break
    else
        echo "Invalid selection. Please enter a number between 1 and $instance_count"
    fi
done

# Get the selected instance
SELECTED_INSTANCE=$(echo "$RDS_INSTANCES" | jq -r ".[$(($selection-1))][0]")
echo "Selected instance: $SELECTED_INSTANCE"

# Get the security group for the selected instance
SECURITY_GROUP=$(aws rds describe-db-instances --profile "$AWS_PROFILE" --db-instance-identifier "$SELECTED_INSTANCE" --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)

if [ -z "$SECURITY_GROUP" ]; then
    echo "No security group found for RDS instance"
    exit 1
fi
echo "Using security group: $SECURITY_GROUP"

# Check if rule already exists
EXISTING_RULE=$(aws ec2 describe-security-groups \
    --profile "$AWS_PROFILE" \
    --group-ids "$SECURITY_GROUP" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`$POSTGRES_PORT\` && ToPort==\`$POSTGRES_PORT\` && contains(IpRanges[].CidrIp, '$IP_ADDRESS/32')]" \
    --output text)

if [ -n "$EXISTING_RULE" ]; then
    echo "Rule for $IP_ADDRESS already exists in security group"
    exit 0
fi

# Add new inbound rule
aws ec2 authorize-security-group-ingress \
    --profile "$AWS_PROFILE" \
    --group-id "$SECURITY_GROUP" \
    --protocol tcp \
    --port $POSTGRES_PORT \
    --cidr "$IP_ADDRESS/32"

if [ $? -eq 0 ]; then
    echo "Successfully added inbound rule for $IP_ADDRESS to security group $SECURITY_GROUP"
else
    echo "Failed to add inbound rule"
    exit 1
fi

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

# Check if RDS instances exist
RDS_INSTANCES=$(aws rds describe-db-instances --profile "$AWS_PROFILE" --query 'DBInstances[*].DBInstanceIdentifier' --output text)
if [ -z "$RDS_INSTANCES" ]; then
    echo "No RDS instances found in account"
    exit 1
fi
echo "Found RDS instances: $RDS_INSTANCES"

# Get the first RDS instance's security group
FIRST_INSTANCE=$(echo "$RDS_INSTANCES" | awk '{print $1}')
SECURITY_GROUP=$(aws rds describe-db-instances --profile "$AWS_PROFILE" --db-instance-identifier "$FIRST_INSTANCE" --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)

if [ -z "$SECURITY_GROUP" ]; then
    echo "No security group found for RDS instance"
    exit 1
fi
echo "Using security group: $SECURITY_GROUP"

# Check if rule already exists
EXISTING_RULE=$(aws ec2 describe-security-groups --profile "$AWS_PROFILE" --group-ids "$SECURITY_GROUP" --query "SecurityGroups[0].IpPermissions[?FromPort==$POSTGRES_PORT && ToPort==$POSTGRES_PORT && contains(IpRanges[].CidrIp, '$IP_ADDRESS/32')]" --output text)

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

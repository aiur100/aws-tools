# AWS Domain Tools

This repository contains scripts for managing domain registrations through AWS Route 53.

## Prerequisites

- AWS CLI installed and configured
- Valid AWS account with payment method
- Required IAM permissions:
  - `route53domains:RegisterDomain`
  - `route53domains:GetDomainDetail`
  - `route53domains:GetOperationDetail`
- Contact details JSON file

## Scripts

### 1. Domain Registration Script (`register-domain.sh`)

Registers a new domain through AWS Route 53.

#### Usage:
```bash
./register-domain.sh <domain-name> [--profile <aws-profile>]
```

#### Examples:
```bash
# Register a domain using default AWS profile
./register-domain.sh example.com

# Register a domain using specific AWS profile
./register-domain.sh example.com --profile myprofile
```

### 2. Domain Status Checker (`check-domain-status.sh`)

Checks the status of a domain registration or operation.

#### Usage:
```bash
# Check by domain name
./check-domain-status.sh --domain <domain-name> [--profile <aws-profile>]

# Check by operation ID
./check-domain-status.sh --operation-id <operation-id> [--profile <aws-profile>]
```

#### Examples:
```bash
# Check domain status using default AWS profile
./check-domain-status.sh --domain example.com

# Check domain status using specific AWS profile
./check-domain-status.sh --domain example.com --profile myprofile

# Check operation status using operation ID
./check-domain-status.sh --operation-id abc123-def456 --profile myprofile
```

### 3. Domain Availability Checker (`domain_checker.sh`)

Checks the availability of multiple domains using AWS Route 53 by processing a CSV file.

#### Usage:
```bash
./domain_checker.sh domains.csv [--profile <aws-profile>]
```

#### CSV File Format
The input CSV file should have the following format:

```csv
domain,checked,available
example.com,false,
another-domain.com,false,
```

- `domain`: The domain name to check (required)
- `checked`: Boolean flag indicating if the domain has been checked (true/false)
- `available`: Will be populated by the script with the availability status

Notes:
- The CSV must include the header row
- Each domain should be on a new line
- The `checked` column should be set to `false` for new domains
- Domains marked as `checked=true` will be skipped
- The script will update the CSV file with availability results

#### Examples:
```bash
# Check domains using default AWS profile
./domain_checker.sh domains.csv

# Check domains using specific AWS profile
./domain_checker.sh domains.csv --profile myprofile
```

### 4. Certificate Creator (`create-certificate.sh`)

Creates an SSL/TLS certificate through AWS Certificate Manager (ACM).

#### Usage:
```bash
./create-certificate.sh --domain <domain-name> [--profile <aws-profile>]
```

#### Examples:
```bash
# Create certificate using default AWS profile
./create-certificate.sh --domain example.com

# Create certificate using specific AWS profile
./create-certificate.sh --domain example.com --profile myprofile
```

### 5. Hosted Zone Lookup (`lookup-hosted-zone.sh`)

Looks up the Route 53 hosted zone ID for a domain.

#### Usage:
```bash
./lookup-hosted-zone.sh --domain <domain-name> [--profile <aws-profile>]
```

#### Examples:
```bash
# Look up hosted zone using default AWS profile
./lookup-hosted-zone.sh --domain example.com

# Look up hosted zone using specific AWS profile
./lookup-hosted-zone.sh --domain example.com --profile myprofile
```

### 6. Certificate Validator (`validate-certificate.sh`)

Adds DNS validation records to Route 53 for AWS Certificate Manager (ACM) certificates.

#### Usage:
```bash
# Validate using certificate ARN
./validate-certificate.sh --arn <certificate-arn> [--profile <aws-profile>]

# Validate using domain name (will look up the certificate ARN)
./validate-certificate.sh --domain <domain-name> [--profile <aws-profile>]
```

#### Examples:
```bash
# Validate certificate using ARN
./validate-certificate.sh --arn arn:aws:acm:region:account:certificate/12345678-1234-1234-1234-123456789012

# Validate certificate using domain name
./validate-certificate.sh --domain example.com

# Validate certificate using domain name and specific AWS profile
./validate-certificate.sh --domain example.com --profile myprofile
```

## Contact Details Configuration

Before registering a domain, create a `contact-details.json` file with your registration information:

```json
{
  "FirstName": "Your-First-Name",
  "LastName": "Your-Last-Name",
  "ContactType": "PERSON",
  "OrganizationName": "Your-Organization",
  "AddressLine1": "Your-Address",
  "City": "Your-City",
  "State": "Your-State",
  "CountryCode": "US",
  "ZipCode": "Your-ZIP",
  "PhoneNumber": "+1.1234567890",
  "Email": "your-email@example.com"
}
```

## Notes

- Domain registration fees apply
- Registration time varies by TLD
- Some domains may require additional verification
- Ensure AWS CLI is properly configured with `aws configure`
- Both scripts support AWS profiles for multi-account management

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

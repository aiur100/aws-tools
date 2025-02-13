# AWS Domain Registration Script

## Overview
This bash script automates the process of registering domains through AWS Route 53 using the AWS CLI. The script handles the domain registration process by submitting contact details and managing privacy protection settings for the registered domain.

## Implementation Specifications

### Prerequisites
- AWS CLI installed and configured
- Valid AWS account with payment method
- Required IAM permissions (`route53domains:RegisterDomain`)
- Contact details JSON file

### Components

1. **Main Script (`register-domain.sh`)**
   - Executable bash script
   - Accepts domain name as command-line argument
   - Handles input validation
   - Executes AWS CLI commands for domain registration
   - Provides success/failure feedback
   - Should optionally allow a parameter called --profile to specify the AWS CLI profile to use
   
2. **Contact Details (`contact-details.json`)**
   - JSON file containing registrant information
   - Required fields:
     - First Name and Last Name
     - Organization Name
     - Address (Street, City, State, ZIP)
     - Country Code
     - Phone Number
     - Email Address

### Features
- Domain registration with AWS Route 53
- One-year registration period
- Privacy protection for all contact types
- Consistent contact details across admin, registrant, and technical contacts
- Input validation
- Error handling

## Usage Instructions

1. **Setup**
   ```bash
   # Make script executable
   chmod +x register-domain.sh
   ```

2. **Create Contact Details**
   Create `contact-details.json` with the following structure:
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

3. **Execute Script**
   ```bash
   ./register-domain.sh example.com
   ```

4. **Post-Registration**
   - Monitor AWS Console for registration status
   - Check email for confirmation messages
   - Verify domain ownership if required
   - Configure DNS settings as needed

## Notes
- Domain registration fees apply
- Registration time varies by TLD
- Some domains may require additional verification
- Ensure AWS CLI is properly configured with `aws configure`


## REGISTRATION STATUS CHECKER
- Accepts domain name as command-line argument or operation ID of a pending registration
- Checks registration status using AWS CLI
- Handles input validation
- Provides success/failure feedback
- Should optionally allow a parameter called --profile to specify the AWS CLI profile to use
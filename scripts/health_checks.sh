#!/bin/bash
# Script to check the health status of the application

# Configuration
API_URL="https://localhost/api"
OUTPUT_FILE="health_status.json"
DETAILED=false

# Function to display usage
display_usage() {
  echo "Health Check Tool"
  echo "----------------"
  echo "This script checks the health status of the application."
  echo ""
  echo "Usage:"
  echo "  $0 [options]"
  echo ""
  echo "Options:"
  echo "  -d, --detailed            Get detailed health status (requires authentication)"
  echo "  -u, --username USERNAME   Specify the username (required for detailed check)"
  echo "  -o, --output FILENAME     Specify output filename (default: health_status.json)"
  echo "  -h, --help                Display this help message"
  echo ""
  echo "If using detailed mode and username is not provided, you will be prompted to enter it."
  echo ""
}

# Parse command line arguments
USERNAME=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -d|--detailed)
      DETAILED=true
      shift
      ;;
    -u|--username)
      USERNAME="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      display_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      display_usage
      exit 1
      ;;
  esac
done

# If detailed check is requested, we need authentication
if $DETAILED; then
  # Prompt for username if not provided
  if [ -z "$USERNAME" ]; then
    read -r -p "Enter username: " USERNAME
  fi

  # Always prompt for password (more secure than command line)
  read -s -r -p "Enter password: " PASSWORD
  echo ""

  if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "Error: Username and password cannot be empty for detailed health check."
    exit 1
  fi

  # Step 1: Get the public key
  echo "Fetching public key..."
  PUBLIC_KEY_RESPONSE=$(curl -k -s "${API_URL}/public-key")
  PUBLIC_KEY=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r '.publicKey')

  if [ -z "$PUBLIC_KEY" ] || [ "$PUBLIC_KEY" == "null" ]; then
    echo "Failed to retrieve public key."
    echo "Server response: $PUBLIC_KEY_RESPONSE"
    exit 1
  fi

  echo "Public key retrieved successfully."

  # Save the public key to a temporary file
  echo "$PUBLIC_KEY" > temp_public_key.pem

  # Function to encrypt and base64 encode a value
  encrypt_value() {
    local value="$1"
    
    # Create a temporary file with the value
    echo -n "$value" > temp_value.txt
    
    # Encrypt with the public key and output in base64
    openssl pkeyutl -encrypt -inkey temp_public_key.pem -pubin -in temp_value.txt | base64 -w 0
    
    # Clean up
    rm temp_value.txt
  }

  # Step 2: Encrypt the username and password
  echo "Encrypting credentials..."
  ENCRYPTED_USERNAME=$(encrypt_value "$USERNAME")
  ENCRYPTED_PASSWORD=$(encrypt_value "$PASSWORD")

  # Clean up
  rm temp_public_key.pem

  echo "Credentials encrypted successfully."

  # Step 3: Login to get access token
  echo "Logging in..."
  LOGIN_RESPONSE=$(curl -k -s -X POST "${API_URL}/login" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"${ENCRYPTED_USERNAME}\",\"password\":\"${ENCRYPTED_PASSWORD}\"}")

  # Extract the access token from the response
  ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.accessToken')

  if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
    echo "Login failed. Response was:"
    echo "$LOGIN_RESPONSE" | jq .
    exit 1
  fi

  echo "Successfully logged in, received access token."

  # Step 4: Get detailed health status
  echo "Fetching detailed health status..."
  HEALTH_RESPONSE=$(curl -k -s "https://localhost/api/health/detailed" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    -H "Content-Type: application/json")

  echo "$HEALTH_RESPONSE" | jq . > "$OUTPUT_FILE"

  # Check if health check was successful
  STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status')

  if [ "$STATUS" = "UP" ]; then
    echo "System is healthy! Detailed health status:"
    echo "$HEALTH_RESPONSE" | jq .
    echo "Results saved to $OUTPUT_FILE"
  else
    echo "System health check indicates issues. Details:"
    echo "$HEALTH_RESPONSE" | jq .
    echo "Results saved to $OUTPUT_FILE"
    exit 1
  fi

else
  # Basic health check (no authentication required)
  echo "Performing basic health check..."
  HEALTH_RESPONSE=$(curl -k -s "https://localhost/api/health")
  
  # Save the response to the output file
  echo "$HEALTH_RESPONSE" | jq . > "$OUTPUT_FILE"
  
  # Check status
  STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status')
  
  if [ "$STATUS" = "UP" ]; then
    echo "System is healthy!"
    echo "$HEALTH_RESPONSE" | jq .
    echo "Results saved to $OUTPUT_FILE"
  else
    echo "System health check indicates issues. Details:"
    echo "$HEALTH_RESPONSE" | jq .
    echo "Results saved to $OUTPUT_FILE"
    exit 1
  fi
fi

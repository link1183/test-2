#!/bin/bash
# Script to fetch database statistics including RSA encryption for login

# Configuration
API_URL="https://localhost/api"
OUTPUT_FILE="db_stats_result.json"

# Function to display usage
display_usage() {
  echo "Database Statistics Tool"
  echo "------------------------"
  echo "This script retrieves database statistics from the API."
  echo ""
  echo "Usage:"
  echo "  $0 [options]"
  echo ""
  echo "Options:"
  echo "  -u, --username USERNAME   Specify the username (optional)"
  echo "  -h, --help                Display this help message"
  echo ""
  echo "If username is not provided, you will be prompted to enter it."
  echo ""
}

# Parse command line arguments
USERNAME=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -u|--username)
      USERNAME="$2"
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

# Prompt for username if not provided
if [ -z "$USERNAME" ]; then
  read -p -r "Enter username: " USERNAME
fi

# Always prompt for password (more secure than command line)
read -s -p -r "Enter password: " PASSWORD
echo ""

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Error: Username and password cannot be empty."
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

# Step 4: Fetch database statistics
echo "Fetching database statistics..."
STATS_RESPONSE=$(curl -k -s -X GET "${API_URL}/admin/db-stats" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

# Save the raw response to a file
echo "$STATS_RESPONSE" | jq . > $OUTPUT_FILE

# Check if the stats request was successful
if echo "$STATS_RESPONSE" | jq -e '.stats' > /dev/null; then
  echo -e "\nDatabase Statistics Summary:"
  echo "============================"
  
  # Extract and display key statistics
  DB_SIZE=$(echo "$STATS_RESPONSE" | jq -r '.stats.size_kb')
  PAGE_COUNT=$(echo "$STATS_RESPONSE" | jq -r '.stats.page_count')
  PAGE_SIZE=$(echo "$STATS_RESPONSE" | jq -r '.stats.page_size')
  SCHEMA_VERSION=$(echo "$STATS_RESPONSE" | jq -r '.stats.schema_version')
  
  echo "Database Size: ${DB_SIZE} KB"
  echo "Page Count: ${PAGE_COUNT}"
  echo "Page Size: ${PAGE_SIZE} bytes"
  echo "Schema Version: ${SCHEMA_VERSION}"
  
  # Display tables
  echo -e "\nDatabase Tables:"
  echo "----------------"
  echo "$STATS_RESPONSE" | jq -r '.stats.tables[] | "Table: \(.name), Indexes: \(.index_count)"'
  
  echo -e "\nDetailed statistics saved to $OUTPUT_FILE"
else
  echo "Failed to fetch database statistics. Response:"
  echo "$STATS_RESPONSE" | jq .
  exit 1
fi

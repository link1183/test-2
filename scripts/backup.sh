#!/bin/bash
# Script to perform database backup including RSA encryption for login

# Configuration
API_URL="https://localhost/api"
OUTPUT_FILE="backup_result.json"

# Function to display usage
display_usage() {
  echo "Database Backup Tool"
  echo "-------------------"
  echo "This script creates a backup of the database through the API."
  echo ""
  echo "Usage:"
  echo "  $0 [options]"
  echo ""
  echo "Options:"
  echo "  -u, --username USERNAME   Specify the username (optional)"
  echo "  -o, --output FILENAME     Specify output filename (default: backup_result.json)"
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

# Prompt for username if not provided
if [ -z "$USERNAME" ]; then
  read -r -p "Enter username: " USERNAME
fi

# Always prompt for password (more secure than command line)
read -s -r -p "Enter password: " PASSWORD
echo ""

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Error: Username and password cannot be empty."
  exit 1
fi

# Step 1: Get the public key
echo "Fetc ing public key..."
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

# Step 4: Trigger database backup
echo "Initiating database backup..."
BACKUP_RESPONSE=$(curl -k -s -X POST "${API_URL}/admin/db-backup" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

echo "$BACKUP_RESPONSE" | jq . > "$OUTPUT_FILE"

# Check if backup was successful
SUCCESS=$(echo "$BACKUP_RESPONSE" | jq -r '.success')

if [ "$SUCCESS" = "true" ]; then
  BACKUP_PATH=$(echo "$BACKUP_RESPONSE" | jq -r '.path')
  echo "Backup completed successfully!"
  echo "Backup file created at: $BACKUP_PATH"
  
  # Ask if user wants to download the backup file
  read -r -p "Do you want to download the backup file? (y/n): " DOWNLOAD
  if [[ $DOWNLOAD == "y" || $DOWNLOAD == "Y" ]]; then
    CONTAINER_NAME=$(docker ps --filter "name=backend" --format "{{.Names}}")
    if [ -z "$CONTAINER_NAME" ]; then
      echo "Could not find the backend container. Please download manually with:"
      echo "docker cp container_name:$BACKUP_PATH ./local_backup.db"
    else
      LOCAL_FILENAME=$(basename "$BACKUP_PATH")
      docker cp "$CONTAINER_NAME":"$BACKUP_PATH" ./"$LOCAL_FILENAME"
      echo "Backup downloaded to ./$LOCAL_FILENAME"
    fi
  else
    echo "To extract the backup file from the Docker container later, run:"
    echo "docker cp container_name:$BACKUP_PATH ./local_backup.db"
  fi
else
  echo "Backup failed. See error details above."
  exit 1
fi

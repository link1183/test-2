#!/bin/bash
# Script to test the link management API endpoints

# Configuration
BASE_URL="https://localhost"
API_URL="${BASE_URL}/api"
OUTPUT_DIR="api_test_results"
USERNAME="agunthe1"
PASSWORD="nFo4nAs53?jSJAnS"  # Replace with actual password

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Function to display test header
test_header() {
  echo -e "\n${BLUE}============================================${NC}"
  echo -e "${BLUE}  $1${NC}"
  echo -e "${BLUE}============================================${NC}"
}

# Function to display test result
test_result() {
  if [ $1 -eq 0 ]; then
    echo -e "${GREEN}✓ $2${NC}"
  else
    echo -e "${RED}✗ $2${NC}"
  fi
}

# Step 1: Get the public key
test_header "1. Getting Public Key"
PUBLIC_KEY_RESPONSE=$(curl -k -s "${API_URL}/public-key")
echo "$PUBLIC_KEY_RESPONSE" > "$OUTPUT_DIR/public_key_response.json"

PUBLIC_KEY=$(echo $PUBLIC_KEY_RESPONSE | jq -r '.publicKey')
if [ -z "$PUBLIC_KEY" ] || [ "$PUBLIC_KEY" == "null" ]; then
  echo -e "${RED}Failed to retrieve public key. Aborting test.${NC}"
  exit 1
fi

test_result 0 "Retrieved public key"

# Save the public key to a temporary file
echo "$PUBLIC_KEY" > temp_public_key.pem

# Function to encrypt and base64 encode a value
encrypt_value() {
  local value="$1"
  
  # Create a temporary file with the value
  echo -n "$value" > temp_value.txt
  
  # Encrypt with the public key and output in base64
  openssl rsautl -encrypt -inkey temp_public_key.pem -pubin -in temp_value.txt | base64 -w 0
  
  # Clean up
  rm temp_value.txt
}

# Step 2: Login to get access token
test_header "2. Logging In"

ENCRYPTED_USERNAME=$(encrypt_value "$USERNAME")
ENCRYPTED_PASSWORD=$(encrypt_value "$PASSWORD")

rm temp_public_key.pem

LOGIN_RESPONSE=$(curl -k -s -X POST "${API_URL}/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${ENCRYPTED_USERNAME}\",\"password\":\"${ENCRYPTED_PASSWORD}\"}")

echo "$LOGIN_RESPONSE" > "$OUTPUT_DIR/login_response.json"

ACCESS_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.accessToken')
if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo -e "${RED}Login failed. Response:${NC}"
  echo $LOGIN_RESPONSE | jq .
  exit 1
fi

test_result 0 "Successfully logged in and received access token"

# Function to make an authenticated API request
api_request() {
  local method="$1"
  local endpoint="$2"
  local data="$3"
  local output_file="$4"
  
  local curl_command="curl -k -s -X $method \"${API_URL}${endpoint}\" \
    -H \"Authorization: Bearer ${ACCESS_TOKEN}\" \
    -H \"Content-Type: application/json\""
  
  if [ ! -z "$data" ]; then
    curl_command="$curl_command -d '$data'"
  fi
  
  echo -e "${YELLOW}Executing:${NC} $curl_command"
  local response=$(eval $curl_command)
  echo "$response" > "$output_file"
  
  # Pretty print the response
  echo "$response" | jq . 
  
  # Check if the response is valid JSON
  if ! jq -e . >/dev/null 2>&1 <<<"$response"; then
    echo -e "${RED}Invalid JSON response:${NC}"
    echo "$response"
    return 1
  fi
  
  # Check for success in the response
  local success=$(echo "$response" | jq -r '.success // false')
  local error=$(echo "$response" | jq -r '.error.message // "No specific error"')
  
  if [ "$success" == "true" ]; then
    return 0
  else
    echo -e "${RED}Error: ${error}${NC}"
    return 1
  fi
}

# Step 3: Create a new link
test_header "3. Creating a New Link"

CREATE_LINK_DATA='{
  "link": "https://example.com/test-api",
  "title": "Test API Link",
  "description": "This link was created by the API test script",
  "docLink": "https://docs.example.com/test",
  "statusId": 1,
  "categoryId": 1,
  "viewIds": [1],
  "keywordIds": [1, 2],
  "managerIds": [1]
}'

# Ensure the JSON is valid and properly formatted
CREATE_LINK_DATA=$(echo "$CREATE_LINK_DATA" | jq '.')

api_request "POST" "/links" "$CREATE_LINK_DATA" "$OUTPUT_DIR/create_link_response.json"
test_result $? "Created new link"

# Get the ID of the newly created link
NEW_LINK_ID=$(cat "$OUTPUT_DIR/create_link_response.json" | jq -r '.link.id')
echo -e "New link ID: ${NEW_LINK_ID}"

# Step 4: Get the link we just created
test_header "4. Getting Link Details"

api_request "GET" "/links/${NEW_LINK_ID}" "" "$OUTPUT_DIR/get_link_response.json"
test_result $? "Retrieved link details"

# Extract and display some information about the link
LINK_TITLE=$(cat "$OUTPUT_DIR/get_link_response.json" | jq -r '.link.title')
echo -e "Link title: ${LINK_TITLE}"

# Step 5: Update the link
test_header "5. Updating Link"

UPDATE_LINK_DATA='{
  "title": "Updated Test API Link",
  "description": "This link was updated by the API test script",
  "viewIds": [1, 2]
}'

api_request "PUT" "/links/${NEW_LINK_ID}" "$UPDATE_LINK_DATA" "$OUTPUT_DIR/update_link_response.json"
test_result $? "Updated link"

# Get the updated link and verify changes
api_request "GET" "/links/${NEW_LINK_ID}" "" "$OUTPUT_DIR/get_updated_link_response.json"
UPDATED_TITLE=$(cat "$OUTPUT_DIR/get_updated_link_response.json" | jq -r '.link.title')
echo -e "Updated title: ${UPDATED_TITLE}"

# Step 6: Delete the link
test_header "6. Deleting Link"

api_request "DELETE" "/links/${NEW_LINK_ID}" "" "$OUTPUT_DIR/delete_link_response.json"
test_result $? "Deleted link"

# Step 7: Verify the link is gone
test_header "7. Verifying Deletion"

curl -k -s -X GET "${API_URL}/links/${NEW_LINK_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" > "$OUTPUT_DIR/verify_deletion_response.json"

NOT_FOUND=$(cat "$OUTPUT_DIR/verify_deletion_response.json" | jq -r '.error.code == "not_found"')
if [ "$NOT_FOUND" = "true" ]; then
  test_result 0 "Link was successfully deleted (returns not found)"
else
  test_result 1 "Link still exists after deletion attempt"
fi

# Step 8: Test error cases
test_header "8. Testing Error Cases"

# Test 1: Try to create a link with missing required fields
INVALID_DATA='{
  "link": "https://example.com/invalid",
  "title": "Invalid Link"
  // Missing required fields
}'

curl -k -s -X POST "${API_URL}/links" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$INVALID_DATA" > "$OUTPUT_DIR/invalid_create_response.json"

BAD_REQUEST=$(cat "$OUTPUT_DIR/invalid_create_response.json" | jq -r '.error.code == "bad_request"')
test_result $? "API correctly rejects incomplete data"

# Test 2: Try to update a non-existent link
NON_EXISTENT_ID=999999
curl -k -s -X PUT "${API_URL}/links/${NON_EXISTENT_ID}" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"title": "This should fail"}' > "$OUTPUT_DIR/non_existent_update_response.json"

NOT_FOUND=$(cat "$OUTPUT_DIR/non_existent_update_response.json" | jq -r '.error.code == "not_found"')
test_result $? "API correctly rejects updating non-existent link"

# Summary
test_header "Test Summary"
echo -e "All test results have been saved to the ${OUTPUT_DIR} directory"
echo -e "You can examine the detailed API responses in the JSON files"
echo -e "${GREEN}Link management API testing complete!${NC}"

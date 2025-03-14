#!/bin/bash

API_URL="https://localhost/api"

USERNAME="agunthe1"
PASSWORD="nFo4nAs53?jSJAnS"

echo "Fetching public key..."
PUBLIC_KEY_RESPONSE=$(curl -k -s "${API_URL}/public-key")
PUBLIC_KEY=$(echo "$PUBLIC_KEY_RESPONSE" | jq -r '.publicKey')

if [ -z "$PUBLIC_KEY" ] || [ "$PUBLIC_KEY" = "null" ]; then
  echo "Failed to retrieve pub key"
  echo "Server response: $PUBLIC_KEY_RESPONSE"
  exit 1
fi

echo "Pub key successfully received"

echo "$PUBLIC_KEY" > temp_public_key.pem

encrypt_value() {
  local value="$1"

  echo -n "$value" > temp_value.txt

  openssl pkeyutl -encrypt -inkey temp_public_key.pem -pubin -in temp_value.txt | base64 -w 0

  rm temp_value.txt
}

echo "Encrypting credentials..."
ENCRYPTED_USERNAME=$(encrypt_value "$USERNAME")
ENCRYPTED_PASSWORD=$(encrypt_value "$PASSWORD")

rm temp_public_key.pem

echo "Credentials encrypted successfully"

echo "Logging in..."
LOGIN_RESPONSE=$(curl -k -s -X POST "${API_URL}/login" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"${ENCRYPTED_USERNAME}\",\"password\":\"${ENCRYPTED_PASSWORD}\"}")

ACCESS_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.accessToken')

if [ "$ACCESS_TOKEN" == "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Login failed. Response was:"
  echo "$LOGIN_RESPONSE" | jq .
  exit 1
fi

echo "successfully logged in"

echo "Testing endpoints..."

echo "GET All Categories"
GET_ALL_RESPONSE=$(curl -k -s -X GET "$API_URL/categories" \
  -H "Authorization: Bearer $ACCESS_TOKEN")


echo "$GET_ALL_RESPONSE" | jq .

printf "\n\n#####################################################################\n\n"

ID=2
echo "GET Category for ID $ID"
GET_CATEGORY_BY_ID=$(curl -k -s -X GET "$API_URL/categories/$ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN")

echo "$GET_CATEGORY_BY_ID" | jq .

printf "\n\n#####################################################################\n\n"

echo "Create Category"
CREATE_CATEGORY_ID=$(curl -k -s -X POST "$API_URL/categories" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"this is a test"}')

echo "$CREATE_CATEGORY_ID" | jq .

printf "\n\n#####################################################################\n\n"

echo "Update Category"
UPDATE_CATEGORY=$(curl -k -s -X PUT "$API_URL/categories/$CREATE_CATEGORY_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"this is a test v2"}')

echo "$UPDATE_CATEGORY" | jq .

printf "\n\n#####################################################################\n\n"

echo "Delete Category"
DELETE_CATEGORY=$(curl -k -s -X DELETE "$API_URL/categories/$CREATE_CATEGORY_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json")

echo "$DELETE_CATEGORY" | jq .



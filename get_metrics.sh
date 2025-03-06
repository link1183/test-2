#!/bin/bash
# Script to retrieve application metrics

# Configuration
API_URL="https://localhost/api"
OUTPUT_FILE="metrics.json"
FORMAT="json" # Options: json, summary

# Function to display usage
display_usage() {
  echo "Application Metrics Tool"
  echo "----------------------"
  echo "This script retrieves metrics from the application API."
  echo ""
  echo "Usage:"
  echo "  $0 [options]"
  echo ""
  echo "Options:"
  echo "  -u, --username USERNAME   Specify the username (required)"
  echo "  -o, --output FILENAME     Specify output filename (default: metrics.json)"
  echo "  -f, --format FORMAT       Output format: json or summary (default: json)"
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
    -f|--format)
      FORMAT="$2"
      if [[ "$FORMAT" != "json" && "$FORMAT" != "summary" ]]; then
        echo "Error: Format must be either 'json' or 'summary'"
        exit 1
      fi
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
  read -p "Enter username: " USERNAME
fi

# Always prompt for password (more secure than command line)
read -s -p "Enter password: " PASSWORD
echo ""

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
  echo "Error: Username and password cannot be empty."
  exit 1
fi

# Step 1: Get the public key
echo "Fetching public key..."
PUBLIC_KEY_RESPONSE=$(curl -k -s "${API_URL}/public-key")
PUBLIC_KEY=$(echo $PUBLIC_KEY_RESPONSE | jq -r '.publicKey')

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
  openssl rsautl -encrypt -inkey temp_public_key.pem -pubin -in temp_value.txt | base64 -w 0
  
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
ACCESS_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.accessToken')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Login failed. Response was:"
  echo $LOGIN_RESPONSE | jq .
  exit 1
fi

echo "Successfully logged in, received access token."

# Step 4: Retrieve metrics
echo "Retrieving metrics..."
METRICS_RESPONSE=$(curl -k -s "https://localhost/api/metrics" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json")

# Save the raw metrics to file
echo $METRICS_RESPONSE | jq . > $OUTPUT_FILE

# Check if we got a valid response
if [[ $(echo $METRICS_RESPONSE | jq -e . 2>/dev/null) ]]; then
  echo "Metrics retrieved successfully. Saved to $OUTPUT_FILE"
  
  # If requested format is summary, create a readable summary
  if [ "$FORMAT" = "summary" ]; then
    echo ""
    echo "=== METRICS SUMMARY ==="
    echo ""
    
    # Timestamp
    TIMESTAMP=$(echo $METRICS_RESPONSE | jq -r '.timestamp')
    echo "Timestamp: $TIMESTAMP"
    echo ""
    
    # HTTP Request Metrics
    echo "=== HTTP REQUESTS ==="
    echo "Total requests: $(echo $METRICS_RESPONSE | jq -r '.counters.http_requests_total // "N/A"')"
    echo "Active requests: $(echo $METRICS_RESPONSE | jq -r '.counters.http_requests_active // "N/A"')"
    
    # Response Codes
    echo ""
    echo "=== RESPONSE CODES ==="
    echo "200 OK responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_200 // "N/A"')"
    echo "400 Bad Request responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_400 // "N/A"')"
    echo "401 Unauthorized responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_401 // "N/A"')"
    echo "403 Forbidden responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_403 // "N/A"')"
    echo "404 Not Found responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_404 // "N/A"')"
    echo "500 Server Error responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_500 // "N/A"')"
    
    # Request Duration
    if [[ $(echo $METRICS_RESPONSE | jq -e '.histograms.http_request_duration_milliseconds' 2>/dev/null) ]]; then
      echo ""
      echo "=== REQUEST DURATION (milliseconds) ==="
      echo "Minimum: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.min // "N/A"')"
      echo "Maximum: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.max // "N/A"')"
      echo "Average: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.avg // "N/A"')"
      echo "50th percentile: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.p50 // "N/A"')"
      echo "95th percentile: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.p95 // "N/A"')"
      echo "99th percentile: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.p99 // "N/A"')"
    fi
    
    # Custom summary file
    SUMMARY_FILE="${OUTPUT_FILE%.json}_summary.txt"
    {
      echo "METRICS SUMMARY"
      echo "Generated: $(date)"
      echo ""
      echo "Timestamp: $TIMESTAMP"
      echo ""
      echo "HTTP REQUESTS"
      echo "Total requests: $(echo $METRICS_RESPONSE | jq -r '.counters.http_requests_total // "N/A"')"
      echo "Active requests: $(echo $METRICS_RESPONSE | jq -r '.counters.http_requests_active // "N/A"')"
      echo ""
      echo "RESPONSE CODES"
      echo "200 OK responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_200 // "N/A"')"
      echo "400 Bad Request responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_400 // "N/A"')"
      echo "401 Unauthorized responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_401 // "N/A"')"
      echo "403 Forbidden responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_403 // "N/A"')"
      echo "404 Not Found responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_404 // "N/A"')"
      echo "500 Server Error responses: $(echo $METRICS_RESPONSE | jq -r '.counters.http_responses_500 // "N/A"')"
      
      if [[ $(echo $METRICS_RESPONSE | jq -e '.histograms.http_request_duration_milliseconds' 2>/dev/null) ]]; then
        echo ""
        echo "REQUEST DURATION (milliseconds)"
        echo "Minimum: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.min // "N/A"')"
        echo "Maximum: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.max // "N/A"')"
        echo "Average: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.avg // "N/A"')"
        echo "50th percentile: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.p50 // "N/A"')"
        echo "95th percentile: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.p95 // "N/A"')"
        echo "99th percentile: $(echo $METRICS_RESPONSE | jq -r '.histograms.http_request_duration_milliseconds.p99 // "N/A"')"
      fi
    } > "$SUMMARY_FILE"
    
    echo ""
    echo "Summary report saved to $SUMMARY_FILE"
  fi
else
  echo "Failed to retrieve metrics. Response was:"
  echo $METRICS_RESPONSE
  exit 1
fi

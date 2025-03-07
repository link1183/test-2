#!/bin/bash
# Script to continuously monitor the system health and metrics

# Configuration
API_URL="https://localhost/api"
HEALTH_OUTPUT="monitor_health.json"
METRICS_OUTPUT="monitor_metrics.json"
INTERVAL=60 # seconds
MAX_RETRIES=3
MONITOR_DURATION="" # Empty means indefinite
SAVE_HISTORY=true
HISTORY_DIR="monitoring_history"

# Function to display usage
display_usage() {
  echo "System Monitoring Tool"
  echo "---------------------"
  echo "This script continuously monitors system health and metrics."
  echo ""
  echo "Usage:"
  echo "  $0 [options]"
  echo ""
  echo "Options:"
  echo "  -u, --username USERNAME   Specify the username for authentication"
  echo "  -i, --interval SECONDS    Specify check interval in seconds (default: 60)"
  echo "  -d, --duration MINUTES    Run for specified minutes then exit (default: indefinite)"
  echo "  -n, --no-history          Don't save historical data, only current state"
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
    -i|--interval)
      INTERVAL="$2"
      shift 2
      ;;
    -d|--duration)
      MONITOR_DURATION="$2"
      shift 2
      ;;
    -n|--no-history)
      SAVE_HISTORY=false
      shift
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

# Create history directory if needed
if $SAVE_HISTORY; then
  mkdir -p "$HISTORY_DIR"
  echo "Saving monitoring history to $HISTORY_DIR/"
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
REFRESH_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.refreshToken')

if [ "$ACCESS_TOKEN" = "null" ] || [ -z "$ACCESS_TOKEN" ]; then
  echo "Login failed. Response was:"
  echo "$LOGIN_RESPONSE" | jq .
  exit 1
fi

echo "Successfully logged in, received access token."

# Function to refresh token
refresh_token() {
  local refresh_response=$(curl -k -s -X POST "${API_URL}/refresh-token" \
    -H "Content-Type: application/json" \
    -d "{\"refreshToken\":\"${REFRESH_TOKEN}\"}")
  
  local new_access_token=$(echo "$refresh_response" | jq -r '.accessToken')
  local new_refresh_token=$(echo "$refresh_response" | jq -r '.refreshToken')
  
  if [ "$new_access_token" = "null" ] || [ -z "$new_access_token" ]; then
    echo "Token refresh failed. Response was:"
    echo "$refresh_response" | jq .
    return 1
  fi
  
  ACCESS_TOKEN=$new_access_token
  REFRESH_TOKEN=$new_refresh_token
  echo "Successfully refreshed token."
  return 0
}

# Function to check health and metrics
check_status() {
  local timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  local retry_count=0
  local success=false
  
  # Get basic health status
  while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = "false" ]; do
    echo "Checking basic health status..."
    HEALTH_RESPONSE=$(curl -k -s "https://localhost/api/health")
    
    if [[ $(echo "$HEALTH_RESPONSE" | jq -e . 2>/dev/null) ]]; then
      success=true
      echo "$HEALTH_RESPONSE" | jq . > $HEALTH_OUTPUT
      
      # Save historical data if enabled
      if $SAVE_HISTORY; then
        echo "$HEALTH_RESPONSE" | jq . > "$HISTORY_DIR/health_${timestamp}.json"
      fi
      
      # Display status
      STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status')
      if [ "$STATUS" = "UP" ]; then
        echo "$(date): System health: UP"
      else
        echo "$(date): System health: DOWN"
      fi
    else
      retry_count=$((retry_count + 1))
      echo "Failed to get health status (attempt $retry_count/$MAX_RETRIES)"
      sleep 2
    fi
  done
  
  # Reset for metrics check
  retry_count=0
  success=false
  
  # Get metrics
  while [ $retry_count -lt $MAX_RETRIES ] && [ "$success" = "false" ]; do
    echo "Checking metrics..."
    METRICS_RESPONSE=$(curl -k -s "https://localhost/api/metrics" \
      -H "Authorization: Bearer ${ACCESS_TOKEN}" \
      -H "Content-Type: application/json")
    
    # Check if we got unauthorized response
    if [[ $(echo "$METRICS_RESPONSE" | jq -e '.error.code == "unauthorized"' 2>/dev/null) == "true" ]]; then
      echo "Token expired, attempting to refresh..."
      if refresh_token; then
        # Try again with new token
        METRICS_RESPONSE=$(curl -k -s "https://localhost/api/metrics" \
          -H "Authorization: Bearer ${ACCESS_TOKEN}" \
          -H "Content-Type: application/json")
      else
        # If refresh failed, exit
        echo "Could not refresh token. Exiting."
        exit 1
      fi
    fi
    
    if [[ $(echo "$METRICS_RESPONSE" | jq -e . 2>/dev/null) ]]; then
      success=true
      echo "$METRICS_RESPONSE" | jq . > $METRICS_OUTPUT
      
      # Save historical data if enabled
      if $SAVE_HISTORY; then
        echo "$METRICS_RESPONSE" | jq . > "$HISTORY_DIR/metrics_${timestamp}.json"
      fi
      
      # Display key metrics
      REQUEST_COUNT=$(echo "$METRICS_RESPONSE" | jq -r '.counters.http_requests_total // "N/A"')
      ACTIVE_REQUESTS=$(echo "$METRICS_RESPONSE" | jq -r '.counters.http_requests_active // "N/A"')
      ERROR_COUNT=$(echo "$METRICS_RESPONSE" | jq -r '.counters.http_errors_total // "N/A"')
      
      echo "$(date): Total requests: $REQUEST_COUNT | Active: $ACTIVE_REQUESTS | Errors: $ERROR_COUNT"
    else
      retry_count=$((retry_count + 1))
      echo "Failed to get metrics (attempt $retry_count/$MAX_RETRIES)"
      sleep 2
    fi
  done
  
  # Print separator line for readability
  echo "------------------------------------------------------"
}

# Main monitoring loop
echo "Starting monitoring (interval: ${INTERVAL}s)"
echo "Press Ctrl+C to stop"
echo "------------------------------------------------------"

# Calculate end time if duration specified
END_TIME=""
if [ -n "$MONITOR_DURATION" ]; then
  END_TIME=("$(date +%s)" + "$MONITOR_DURATION" * 60)
  echo "Monitoring will run for $MONITOR_DURATION minutes"
fi

# Monitor indefinitely or until the specified duration
while true; do
  # Check if we've reached the end time
  if [ -n "$END_TIME" ] && [ "$(date +%s)" -ge "$END_TIME" ]; then
    echo "Monitoring duration ($MONITOR_DURATION minutes) completed."
    break
  fi
  
  # Check status
  check_status
  
  # Wait for the next interval
  sleep "$INTERVAL"
done

echo "Monitoring complete. Final results saved to $HEALTH_OUTPUT and $METRICS_OUTPUT"
if $SAVE_HISTORY; then
  echo "Monitoring history saved to $HISTORY_DIR/"
fi

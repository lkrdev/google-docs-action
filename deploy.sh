#!/bin/bash
set -e

echo "=== Google Docs Looker Action Deployment ==="

# 1. Check Google Cloud Project
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
  echo "Error: No Google Cloud project is set."
  echo "Please set your project using: gcloud config set project <PROJECT-ID>"
  exit 1
fi
echo "Using Google Cloud Project: $PROJECT_ID"

# 2. Get/Prompt for configuration
if [ -z "$GOOGLE_DRIVE_CLIENT_ID" ]; then
  read -p "Enter GOOGLE_DRIVE_CLIENT_ID: " GOOGLE_DRIVE_CLIENT_ID
fi
# Check if Google Drive Client Secret is already in Secret Manager
HAS_DRIVE_SECRET=false
if gcloud secrets describe google-drive-client-secret &>/dev/null; then
  HAS_DRIVE_SECRET=true
fi

if [ "$HAS_DRIVE_SECRET" = false ] && [ -z "$GOOGLE_DRIVE_CLIENT_SECRET" ]; then
  read -sp "Enter GOOGLE_DRIVE_CLIENT_SECRET: " GOOGLE_DRIVE_CLIENT_SECRET
  echo ""
fi

# 3. Prompt for Looker Registration (Optional)
read -p "Do you want to automatically register this action in Looker? (y/N): " REGISTER_LOOKER
if [[ "$REGISTER_LOOKER" =~ ^[Yy]$ ]]; then
  if [ -z "$LOOKERSDK_BASE_URL" ]; then
    read -p "Enter Looker Base URL (e.g. https://yourcompany.looker.com): " LOOKERSDK_BASE_URL
  fi
  if [ -z "$LOOKERSDK_CLIENT_ID" ]; then
    read -p "Enter Looker Client ID: " LOOKERSDK_CLIENT_ID
  fi
  if [ -z "$LOOKERSDK_CLIENT_SECRET" ]; then
    read -sp "Enter Looker Client Secret: " LOOKERSDK_CLIENT_SECRET
    echo ""
  fi
fi

# 4. Enable required APIs
echo "Enabling Google Cloud APIs (this may take a minute)..."
gcloud services enable \
  run.googleapis.com \
  secretmanager.googleapis.com \
  drive.googleapis.com \
  docs.googleapis.com \
  cloudbuild.googleapis.com

# 5. Create Secrets in Secret Manager if they do not exist
create_secret_if_missing() {
  local secret_name=$1
  local secret_val=$2
  if ! gcloud secrets describe "$secret_name" &>/dev/null; then
    echo "Creating secret $secret_name..."
    gcloud secrets create "$secret_name" --replication-policy="automatic"
    echo -n "$secret_val" | gcloud secrets versions add "$secret_name" --data-file=-
  else
    echo "Secret $secret_name already exists."
  fi
}

# Generate secrets if not already stored or provided
CIPHER_MASTER=$(openssl rand -hex 32)
ACTION_HUB_SECRET=$(openssl rand -hex 32)

# Check if secret manager already has them, if so, retrieve them to compute the key token
if gcloud secrets describe cipher-master &>/dev/null; then
  echo "Retrieving existing cipher-master secret..."
  CIPHER_MASTER=$(gcloud secrets versions access latest --secret="cipher-master")
else
  create_secret_if_missing "cipher-master" "$CIPHER_MASTER"
fi

if gcloud secrets describe action-hub-secret &>/dev/null; then
  echo "Retrieving existing action-hub-secret secret..."
  ACTION_HUB_SECRET=$(gcloud secrets versions access latest --secret="action-hub-secret")
else
  create_secret_if_missing "action-hub-secret" "$ACTION_HUB_SECRET"
fi

if [ "$HAS_DRIVE_SECRET" = false ]; then
  if [ -z "$GOOGLE_DRIVE_CLIENT_SECRET" ]; then
    echo "Error: GOOGLE_DRIVE_CLIENT_SECRET is required to initialize the secret."
    exit 1
  fi
  create_secret_if_missing "google-drive-client-secret" "$GOOGLE_DRIVE_CLIENT_SECRET"
fi

# 6. Deploy to Google Cloud Run
echo "Deploying service to Google Cloud Run..."
REGION=${CLOUD_RUN_REGION:-us-central1}

gcloud run deploy google-docs-action \
  --source . \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --set-env-vars="GOOGLE_DRIVE_CLIENT_ID=$GOOGLE_DRIVE_CLIENT_ID,ACTION_HUB_LABEL=Google Docs" \
  --set-secrets="CIPHER_MASTER=cipher-master:latest,ACTION_HUB_SECRET=action-hub-secret:latest,GOOGLE_DRIVE_CLIENT_SECRET=google-drive-client-secret:latest"

# 7. Post-deployment configuration (Update URL)
SERVICE_URL=$(gcloud run services describe google-docs-action \
  --platform managed \
  --region "$REGION" \
  --format="value(status.url)")

echo "Deployed Service URL: $SERVICE_URL"
echo "Updating ACTION_HUB_BASE_URL to $SERVICE_URL..."
gcloud run services update google-docs-action \
  --platform managed \
  --region "$REGION" \
  --update-env-vars="ACTION_HUB_BASE_URL=$SERVICE_URL"

# Generate API Key Token
API_KEY_TOKEN=$(node -e "
const crypto = require('crypto');
const secret = '$ACTION_HUB_SECRET';
const nonce = crypto.randomBytes(32).toString('hex');
const digest = crypto.createHmac('sha512', secret).update(nonce).digest('hex');
console.log(nonce + '/' + digest);
")

# 8. Register in Looker if selected
if [[ "$REGISTER_LOOKER" =~ ^[Yy]$ ]]; then
  echo "Registering with Looker Instance..."
  
  # Export variables needed by lkr-dev-cli and Python script
  export SERVICE_URL
  export API_KEY_TOKEN
  export LOOKERSDK_CLIENT_ID
  export LOOKERSDK_CLIENT_SECRET
  export LOOKERSDK_BASE_URL

  # Install uv if not found
  if ! command -v uv &> /dev/null; then
    echo "uv not found. Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.local/bin/env
  fi

  uvx --from lkr-dev-cli[codemode] lkr code-mode sandbox --file "$(dirname "$0")/bin/register_integration.py"
fi

echo "========================================================================="
echo " Looker Action Hub Registration Details"
echo "========================================================================="
echo "Use the following details to register the Action Hub in Looker:"
echo ""
echo "1. Action Hub URL:"
echo "   $SERVICE_URL"
echo ""
echo "2. Authorization Token (API Key):"
echo "   $API_KEY_TOKEN"
echo "========================================================================="

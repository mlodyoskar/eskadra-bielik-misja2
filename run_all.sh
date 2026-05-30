#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKIP_APIS=false
SKIP_IAM=false
SKIP_INGEST=false

usage() {
  cat <<'EOF'
Usage: ./run_all.sh [options]

Deploy the full Bielik RAG stack:
  1. Load environment variables from setup_env.sh
  2. Enable required Google Cloud APIs
  3. Grant the current user Cloud Run invoker permissions
  4. Deploy the Bielik LLM service
  5. Deploy the EmbeddingGemma service
  6. Initialize the BigQuery vector store
  7. Deploy the orchestration API
  8. Ingest the sample hotel rules CSV

Options:
  --skip-apis      Do not enable Google Cloud APIs
  --skip-iam       Do not add Cloud Run invoker IAM binding
  --skip-ingest    Do not upload vector_store/hotel_rules.csv
  -h, --help       Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-apis)
      SKIP_APIS=true
      ;;
    --skip-iam)
      SKIP_IAM=true
      ;;
    --skip-ingest)
      SKIP_INGEST=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

run_step() {
  echo
  echo "==> $1"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

cd "$SCRIPT_DIR"

require_command gcloud
require_command curl
require_command python3

run_step "Loading environment variables"
source "$SCRIPT_DIR/setup_env.sh"

if [ -z "${PROJECT_ID:-}" ] || [ -z "${REGION:-}" ] || [ -z "${LLM_SERVICE:-}" ] || [ -z "${EMBEDDING_SERVICE:-}" ]; then
  echo "Required environment variables are missing after sourcing setup_env.sh" >&2
  exit 1
fi

if [ "$SKIP_APIS" = false ]; then
  run_step "Enabling required Google Cloud APIs"
  gcloud services enable run.googleapis.com
  gcloud services enable cloudbuild.googleapis.com
  gcloud services enable artifactregistry.googleapis.com
  gcloud services enable bigquery.googleapis.com
else
  run_step "Skipping API enablement"
fi

if [ "$SKIP_IAM" = false ]; then
  run_step "Granting Cloud Run invoker permission to the current gcloud user"
  GCLOUD_ACCOUNT="$(gcloud config get-value account)"
  gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:$GCLOUD_ACCOUNT" \
    --role="roles/run.invoker"
else
  run_step "Skipping IAM binding"
fi

run_step "Deploying Bielik LLM service"
(
  cd "$SCRIPT_DIR/llm"
  ./cloud_run.sh
)

run_step "Deploying EmbeddingGemma service"
(
  cd "$SCRIPT_DIR/embedding_model"
  ./cloud_run.sh
)

run_step "Initializing BigQuery vector store"
python3 "$SCRIPT_DIR/vector_store/init_db.py"

run_step "Deploying orchestration API"
(
  cd "$SCRIPT_DIR/orchestration"
  ./cloud_run.sh
)

run_step "Reading orchestration URL"
ORCHESTRATION_URL="$(gcloud run services describe orchestration-api --region "$REGION" --format="value(status.url)")"
export ORCHESTRATION_URL

if [ "$SKIP_INGEST" = false ]; then
  run_step "Ingesting sample hotel rules"
  curl -X POST "$ORCHESTRATION_URL/ingest" \
    -F "file=@$SCRIPT_DIR/vector_store/hotel_rules.csv"
else
  run_step "Skipping sample data ingest"
fi

echo
echo "Done."
echo "Orchestration URL: $ORCHESTRATION_URL"

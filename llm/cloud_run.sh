#!/bin/bash

gcloud run deploy $LLM_SERVICE \
  --source . \
  --region $REGION \
  --concurrency 1 \
  --cpu 8 \
  --gpu 1 \
  --gpu-type nvidia-l4 \
  --no-allow-unauthenticated \
  --no-cpu-throttling \
  --no-gpu-zonal-redundancy \
  --set-env-vars OLLAMA_NUM_PARALLEL=1,OLLAMA_MAX_LOADED_MODELS=1 \
  --max-instances 1 \
  --memory 32Gi \
  --timeout=600 \
  --labels dev-tutorial=dos-codelab-bielik-rag

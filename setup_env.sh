#!/bin/bash

# Ustawienie zmiennych środowiskowych
export PROJECT_ID=$(gcloud config get-value project)
export REGION="europe-west1"
export EMBEDDING_SERVICE="embedding-gemma"
export LLM_SERVICE="bielik"
export LLM_MODEL="SpeakLeash/bielik-11b-v3.0-instruct:Q8_0"
export BIGQUERY_DATASET="rag_dataset"
export BIGQUERY_TABLE="hotel_rules"

echo "Wczytano zmienne środowiskowe"

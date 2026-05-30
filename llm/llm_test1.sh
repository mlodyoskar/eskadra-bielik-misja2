#!/bin/bash

#uzyskanie URL usługi LLM
export LLM_SERVICE_URL=$(gcloud run services describe $LLM_SERVICE --region $REGION --format="value(status.url)")

#uzyskanie tokenu autoryzacyjnego
export ID_TOKEN=$(gcloud auth print-identity-token)

: "${LLM_MODEL:=SpeakLeash/bielik-11b-v3.0-instruct:Q8_0}"

curl -X POST "$LLM_SERVICE_URL/api/chat" \
    -H "Authorization: Bearer $ID_TOKEN" \
    -H "Content-Type: application/json" \
    --data-binary @- <<EOF
    {
        "model": "$LLM_MODEL",
        "messages": [{ "role": "user", "content": "Jak często powinien być mierzony poziom chloru w basenie?" }],
        "stream": false
    }
EOF

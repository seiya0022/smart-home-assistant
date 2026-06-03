#!/usr/bin/env bash
set -euo pipefail

OLLAMA_URL="${OLLAMA_URL:-http://10.0.0.15:11434}"
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5:3b}"
PROMPT="${PROMPT:-Return only: OK}"

echo "Ollama URL:   ${OLLAMA_URL}"
echo "Ollama model: ${OLLAMA_MODEL}"
echo

echo "== /api/tags (reachability) =="
curl -fsS --connect-timeout 2 --max-time 5 "${OLLAMA_URL}/api/tags" | head -c 400
echo
echo

echo "== /api/chat (latency) =="
/usr/bin/time -f "elapsed_sec=%e" \
  curl -fsS --max-time 120 "${OLLAMA_URL}/api/chat" \
    -H 'Content-Type: application/json' \
    -d "{\"model\":\"${OLLAMA_MODEL}\",\"stream\":false,\"messages\":[{\"role\":\"user\",\"content\":\"${PROMPT}\"}]}" \
  | head -c 400
echo

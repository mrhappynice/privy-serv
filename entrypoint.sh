#!/bin/bash

# Default values
CODE_SERVER_PORT="${PORT:-8080}" # Use PORT env var if set, otherwise 8080
CODE_SERVER_PASSWORD="${PASSWORD:-}" # Use PASSWORD env var if set
LLAMA_SERVER_PORT="${LLAMA_PORT:-8000}" # Use LLAMA_PORT env var if set, otherwise 8000

# Start code-server
echo "Starting code-server on port ${CODE_SERVER_PORT}"
if [ -n "${CODE_SERVER_PASSWORD}" ]; then
  echo "Using password: ${CODE_SERVER_PASSWORD}"
  PASSWORD="${CODE_SERVER_PASSWORD}" code-server --bind-addr "0.0.0.0:${CODE_SERVER_PORT}" --auth password --user-data-dir /app/code-server-data --extensions-dir /app/code-server-data/extensions /workspace
else
  echo "Starting code-server without a password (auth none). Set PASSWORD env var for security."
  code-server --bind-addr "0.0.0.0:${CODE_SERVER_PORT}" --auth none --user-data-dir /app/code-server-data --extensions-dir /app/code-server-data/extensions /workspace
fi

# You can add commands here to start llama.cpp server if needed, for example:
# echo "Starting llama.cpp server on port ${LLAMA_SERVER_PORT}"
# /usr/local/bin/llama-server -m /path/to/your/model.gguf -c 2048 --port ${LLAMA_SERVER_PORT} --host 0.0.0.0 &

# Keep the container running (if code-server is not run in the foreground or if you have background services)
# wait

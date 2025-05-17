# Step 1: Base Image - Ubuntu with CUDA for GPU support on Runpod
# Using a Runpod provided base image is often a good starting point if available,
# otherwise, an official NVIDIA CUDA image is a solid choice.
# For this example, we'll use an NVIDIA CUDA base image.
# You might want to choose a specific CUDA version compatible with your target GPU on Runpod.
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# Step 2: Environment Variables
ENV DEBIAN_FRONTEND=noninteractive
ENV CODE_SERVER_VERSION=4.91.1
ENV LLAMA_CPP_DIR=/app/llama.cpp
ENV PATH="/app/code-server/bin:${PATH}"
ENV XDG_DATA_HOME="/app/code-server-data"
ENV XDG_CONFIG_HOME="/app/code-server-config"

# Step 3: Install Dependencies
# - Common utilities: wget, git, sudo, nano (for debugging)
# - Build tools for llama.cpp: build-essential, cmake, pkg-config
# - Python (often useful with llama.cpp and for other tools)
# - Dependencies for code-server (libasound2, etc.)
RUN apt-get update && apt-get install -y \
    wget \
    git \
    sudo \
    nano \
    build-essential \
    cmake \
    pkg-config \
    python3 \
    python3-pip \
    libasound2 \
    libxshmfence-dev \
    libgbm-dev \
    libxkbfile-dev \
    libnss3 \
    libsecret-1-0 \
    && rm -rf /var/lib/apt/lists/*

# Step 4: Install code-server
RUN mkdir -p /app/code-server /app/code-server-data /app/code-server-config /workspace \
    && wget "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-amd64.tar.gz" -O /tmp/code-server.tar.gz \
    && tar -xzf /tmp/code-server.tar.gz -C /app/code-server --strip-components=1 \
    && rm /tmp/code-server.tar.gz \
    && ln -s /app/code-server/bin/code-server /usr/local/bin/code-server

# Step 5: Install code-server Extensions (Continue.dev)
# Find the extension ID from Open VSX Registry (https://open-vsx.org/)
# For Continue.dev, the ID is usually Continue.continue
RUN code-server --install-extension Continue.continue --extensions-dir /app/code-server-data/extensions --user-data-dir /app/code-server-data
# Add any other extensions you need here using the same format:
# RUN code-server --install-extension <publisher>.<extension_name> --extensions-dir /app/code-server-data/extensions --user-data-dir /app/code-server-data

# Step 6: Install llama.cpp
# This will compile llama.cpp with CUDA support (cuBLAS)
RUN git clone --depth 1 https://github.com/ggml-org/llama.cpp.git ${LLAMA_CPP_DIR}
WORKDIR ${LLAMA_CPP_DIR}
# Adjust CMAKE_CUDA_ARCHITECTURES based on the GPUs you plan to use on Runpod
# Common values: 70 (V100), 75 (T4), 80 (A100), 86 (RTX30xx), 89 (RTX40xx), 90 (H100)
# Using a few common ones for wider compatibility. Remove or add as needed.
RUN mkdir build && cd build && \
    cmake .. -DLLAMA_CUBLAS=ON -DCMAKE_CUDA_ARCHITECTURES="70;75;80;86;89;90" && \
    cmake --build . --config Release -j$(nproc) && \
    # Optional: Move main llama.cpp executables to a more accessible path
    cp main /usr/local/bin/llama-main && \
    cp server /usr/local/bin/llama-server

# Step 7: Setup User and Workspace
# Runpod typically runs containers as root, but you can set up a non-root user if preferred.
# For simplicity, we'll continue as root, which is common for Runpod.
# The /workspace directory will be your default project folder in code-server.
WORKDIR /workspace

# Step 8: Expose Ports
# code-server default port
EXPOSE 8080
# llama.cpp server default port (if you run it as a server)
EXPOSE 8000

# Step 9: Startup Script (Optional but Recommended for Flexibility)
# You can use a startup script to launch code-server and any other services.
# For Runpod, you might set the password or other args via environment variables.
# We will define a simple entrypoint here. For Runpod, you often override the command.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set a default password for code-server.
# IMPORTANT: For production, manage secrets securely. Runpod allows setting env vars.
ENV PASSWORD="yoursecurepassword"
# If you want to use Runpod's $RUNPOD_TCP_PORT_8080 for code-server
# ENV PORT=$RUNPOD_TCP_PORT_8080

ENTRYPOINT ["/entrypoint.sh"]

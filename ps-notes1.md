Okay, here's a step-by-step guide to creating a Docker template for a Runpod instance that includes code-server and llama.cpp, along with the Continue.dev extension for code-server. This guide will provide you with a Dockerfile and instructions on how to build and use it.

**Understanding the Components:**

  * **Runpod:** A cloud platform offering GPU and CPU instances, ideal for running AI/ML workloads and development environments. You'll deploy your custom Docker image here.
  * **Docker:** A platform to create, deploy, and run applications in containers. We'll define our environment in a `Dockerfile`.
  * **code-server:** A version of VS Code that runs on a remote server and is accessible through a web browser. This allows for a rich development experience.
  * **llama.cpp:** A C/C++ implementation for running LLaMA models, known for its efficiency and ability to run on various hardware (CPU and GPU).
  * **Continue.dev extension:** A VS Code extension that enhances AI-assisted development, which we'll install into our code-server instance.

-----

**Step 1: Prerequisites**

1.  **Docker Installed:** Ensure you have Docker installed on your local machine. You can get it from [Docker's website](https://www.docker.com/get-started).
2.  **Runpod Account:** You'll need a Runpod account. Sign up at [Runpod.io](https://www.runpod.io/).
3.  **Text Editor:** A text editor like VS Code (locally), Sublime Text, or Notepad++ to create the `Dockerfile`.
4.  **(Optional but Recommended) Docker Hub Account:** To push your custom Docker image to a registry, making it easily accessible by Runpod. You can create a free account at [Docker Hub](https://hub.docker.com/).

-----

**Step 2: The Dockerfile**

Create a new file named `Dockerfile` (no extension) in an empty directory on your local machine. Paste the following content into it:

```dockerfile
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
```

-----

**Step 3: Create the `entrypoint.sh` Script**

In the same directory as your `Dockerfile`, create a file named `entrypoint.sh` and add the following:

```bash
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
```

**Explanation of `entrypoint.sh`:**

  * It sets default ports for code-server and the llama.cpp server (if you choose to run it automatically).
  * It starts `code-server`.
      * It listens on all network interfaces (`0.0.0.0`).
      * It uses the specified port.
      * It sets authentication to `password` if the `PASSWORD` environment variable is set, otherwise it starts with `none` (less secure, for quick testing). **It's highly recommended to set a password.**
      * It specifies the user data and extensions directories.
      * It opens the `/workspace` directory by default.
  * There's a commented-out section showing how you might start the `llama.cpp` server. You'll need to provide a path to a model file (`.gguf` format).

-----

**Step 4: Build the Docker Image**

1.  **Open your terminal or command prompt.**

2.  **Navigate to the directory** where you saved `Dockerfile` and `entrypoint.sh`.

3.  **Build the image:**

      * Replace `yourusername/my-runpod-dev-env` with your Docker Hub username and a name for your image.
      * The `.` at the end signifies the current directory as the build context.

    <!-- end list -->

    ```bash
    docker build -t yourusername/my-runpod-dev-env:latest .
    ```

    This process might take a while, especially the first time, as it downloads the base image and compiles llama.cpp.

    **Helpful Hint: GPU Architecture for llama.cpp**
    The `Dockerfile` includes `-DCMAKE_CUDA_ARCHITECTURES="70;75;80;86;89;90"` for `llama.cpp` compilation. These numbers correspond to different NVIDIA GPU architectures (e.g., 75 for T4, 80 for A100, 86 for RTX 30-series, 89 for RTX 40-series, 90 for H100). Including multiple architectures makes your Docker image more versatile but also increases compilation time and image size slightly. You can tailor this list to the specific GPUs you intend to use on Runpod to optimize. If you know you'll only use an RTX 4090, you could just use `89`.

-----

**Step 5: (Optional but Recommended) Push the Image to Docker Hub**

1.  **Log in to Docker Hub (if you haven't already):**

    ```bash
    docker login
    ```

    Enter your Docker Hub username and password when prompted.

2.  **Push the image:**

    ```bash
    docker push yourusername/my-runpod-dev-env:latest
    ```

-----

**Step 6: Deploy on Runpod**

1.  **Log in to your Runpod Dashboard.**

2.  **Go to "Templates" (or "My Templates") and click "New Template".**

      * **Template Name:** Give it a descriptive name (e.g., "Code-LlamaCpp-Dev").
      * **Container Image:** Enter the name of your Docker image.
          * If you pushed to Docker Hub: `yourusername/my-runpod-dev-env:latest`
          * If you plan to use a private registry, configure that accordingly.
      * **Container Disk:** Allocate sufficient disk space (e.g., 20-30 GB, more if you plan to download large models).
      * **Volume Path (Optional but Recommended for Persistent Workspace):**
          * Set it to `/workspace` if you want your `/workspace` directory inside the container to be persistent across pod restarts. You'll also need to define a Volume size.
      * **Environment Variables:**
          * You *must* set the `PASSWORD` environment variable here to a secure password for `code-server`. E.g., `PASSWORD=YourSuperStrongPassword123!`.
          * (Optional) `PORT=8080` (Runpod will map this, but good to be explicit).
          * (Optional) `LLAMA_PORT=8000` if you plan to auto-start the llama.cpp server.
      * **Exposed Ports:**
          * Runpod automatically detects `EXPOSE` in Dockerfiles but it's good practice to ensure your desired ports (e.g., `8080` for code-server, `8000` for llama.cpp server) are listed or that Runpod's HTTP port mapping will work for you. Runpod usually maps an internal port to an external HTTPS URL.
      * **Container Start Command (Override):**
          * You can leave this blank to use the `ENTRYPOINT` from your Dockerfile.
          * Or, you can provide specific commands here if needed, which will override the Dockerfile's `ENTRYPOINT` and `CMD`. For our setup, the `entrypoint.sh` script should handle things well.

3.  **Save the Template.**

4.  **Deploy a Pod:**

      * Go to "Secure Cloud" or "Community Cloud".
      * Select a GPU instance that meets your needs (for `llama.cpp` with GPU, ensure it has enough VRAM for your models).
      * When configuring the pod, select your newly created template.
      * Adjust "Volume Storage" if you didn't set a default volume in the template and want persistent `/workspace` storage.
      * Click "Deploy".

5.  **Connect to Your Instance:**

      * Once the pod is running, go to "My Pods".
      * You'll see a "Connect" button. Click it.
      * Runpod provides different connection options. For `code-server`, you'll typically use the "Connect to HTTP Service [Port XXXX]" link that Runpod sets up (it will usually map your container's port 8080 to a public URL).
      * Open the provided link in your browser. You should see the `code-server` login page. Enter the password you set in the environment variables.

-----

**Step 7: Using Your Environment**

1.  **code-server:** You'll have a VS Code interface in your browser.

      * The Continue.dev extension should be installed and available in the activity bar.
      * Your default working directory will be `/workspace`.
      * Use the integrated terminal in `code-server` (Ctrl+`or Terminal > New Terminal) to run commands, including`llama.cpp\`.

2.  **llama.cpp:**

      * **Download Models:** You'll need to download LLaMA models in GGUF format. You can do this within the `code-server` terminal using `wget` or `git lfs`.
        ```bash
        # Example:
        # cd /workspace
        # mkdir models
        # cd models
        # wget https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf
        ```
      * **Run llama.cpp:**
          * **Interactive Mode:**
            ```bash
            llama-main -m /workspace/models/your_model_name.gguf -c 4096 -n 512 --repeat_penalty 1.1 -p "Your prompt here" --color -i --n-gpu-layers 35
            ```
            (Adjust `-m` with your model path, `-c` for context size, and `--n-gpu-layers` to offload layers to GPU. Set `--n-gpu-layers` to a high number like 99 or 1000 to try and offload all possible layers, or to a specific number based on your GPU VRAM).
          * **Server Mode:**
            ```bash
            llama-server -m /workspace/models/your_model_name.gguf -c 4096 --port 8000 --host 0.0.0.0 --n-gpu-layers 35
            ```
            You can then interact with it via HTTP requests (e.g., from another terminal or application). The Continue.dev extension might also be configurable to point to a local llama.cpp server endpoint.

-----

**Helpful Hints & Further Customization:**

  * **Runpod Storage:**
      * **Persistent Volume:** Strongly recommended for `/workspace` (and potentially `/app/code-server-data` if you want to keep code-server settings/extensions persistent independently of the container image updates). This way, your code, downloaded models, and extension settings aren't lost if you stop and restart the pod. Configure this in the Runpod template or when launching the pod.
      * **Network Storage:** For very large datasets or models, consider using Runpod's Network Storage.
  * **Managing `llama.cpp` Models:**
      * Include model download commands in your `entrypoint.sh` if you want specific models to be available on startup (but be mindful of startup times).
      * Use a persistent volume to store downloaded models so you don't have to redownload them every time the pod starts (unless the volume is fresh).
  * **code-server Configuration:**
      * You can further customize `code-server` via its `config.yaml` file, which would be located in `/app/code-server-config/.config/code-server/config.yaml` based on our `XDG_CONFIG_HOME` setting.
      * The `--user-data-dir` and `--extensions-dir` flags ensure that code-server keeps its data and extensions in a predictable location, which is good for persistence if you mount these as volumes.
  * **Security:**
      * **ALWAYS set a strong password for `code-server` via the `PASSWORD` environment variable in Runpod.**
      * Be mindful of any other services you expose.
  * **Cost Management:**
      * Stop your Runpod pods when you're not actively using them to save on costs.
  * **Troubleshooting:**
      * Use `docker logs <container_id>` locally if you are testing the build.
      * In Runpod, check the pod logs for any error messages during startup.
      * Connect via SSH (if enabled for the pod) or use the web terminal provided by Runpod to debug inside the running container.
  * **Updating:** To update `code-server` or `llama.cpp`, you'll need to:
    1.  Modify the `Dockerfile` (e.g., change `CODE_SERVER_VERSION` or `git pull` in the `llama.cpp` directory build steps).
    2.  Rebuild the Docker image.
    3.  Push the new image to your registry.
    4.  Update your Runpod template to use the new image tag (e.g., `:latest` or a new version tag).
    5.  Restart your pod (or deploy a new one with the updated template).

This comprehensive guide should give you a robust and flexible development environment on Runpod. Remember to adapt paths, versions, and configurations to your specific needs.

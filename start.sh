#!/usr/bin/env bash
set -e

# Use libtcmalloc for better memory management
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1)"
if [ -n "$TCMALLOC" ]; then
    export LD_PRELOAD="${TCMALLOC}"
    echo "Using tcmalloc: $TCMALLOC"
else
    echo "tcmalloc not found, proceeding without it."
fi

# Execute additional_params.sh if it exists
if [ -f "/workspace/additional_params.sh" ]; then
    chmod +x /workspace/additional_params.sh
    echo "Executing additional_params.sh..."
    /workspace/additional_params.sh
else
    echo "additional_params.sh not found in /workspace. Skipping..."
fi

# Set the network volume path
NETWORK_VOLUME="/workspace"

# Check if NETWORK_VOLUME exists; if not, use root directory instead
if [ ! -d "$NETWORK_VOLUME" ]; then
    echo "NETWORK_VOLUME directory '$NETWORK_VOLUME' does not exist. You are NOT using a network volume. Setting NETWORK_VOLUME to '/' (root directory)."
    NETWORK_VOLUME="/"
    # Start JupyterLab on root directory if NETWORK_VOLUME doesn't exist
    echo "Starting JupyterLab on root directory..."
    jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir=/ &
else
    # Start JupyterLab on NETWORK_VOLUME if it exists
    echo "NETWORK_VOLUME directory exists. Starting JupyterLab on $NETWORK_VOLUME..."
    jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir="$NETWORK_VOLUME" &
fi

COMFYUI_DIR="$NETWORK_VOLUME/ComfyUI"

# 1. Ensure ComfyUI application code is present
echo "Ensuring ComfyUI application code is present in $COMFYUI_DIR..."
if [ ! -d "$COMFYUI_DIR/.git" ]; then # Check if it's a git repository
    if [ -d "$COMFYUI_DIR" ] && [ "$(ls -A $COMFYUI_DIR)" ]; then # If directory exists and is not empty but not a .git repo
        echo "Warning: $COMFYUI_DIR exists but is not a git repository or might be incomplete. Consider backing it up and removing it for a fresh clone."
        # Optionally, you could add logic here to backup and remove, or just proceed.
        # For now, we'll assume if .git is missing, we need to handle it.
    fi

    if [ -d "/ComfyUI" ]; then # Check for a bundled version (e.g., in Docker image root)
        echo "Found bundled ComfyUI at /ComfyUI. Moving it to $COMFYUI_DIR..."
        if [ -d "$COMFYUI_DIR" ]; then
             echo "Removing existing $COMFYUI_DIR before moving bundled version."
             rm -rf "$COMFYUI_DIR" # Remove existing to avoid mv conflicts
        fi
        mkdir -p "$(dirname "$COMFYUI_DIR")" # Ensure parent directory exists
        mv /ComfyUI "$COMFYUI_DIR"
    elif [ ! -d "$COMFYUI_DIR" ]; then # If no bundled version and target doesn't exist, clone it
        echo "Cloning ComfyUI repository to $COMFYUI_DIR..."
        git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
    else
        echo "$COMFYUI_DIR exists but .git folder is missing. Manual check might be needed if it's not the bundled version."
    fi
else
    echo "ComfyUI git repository already exists in $COMFYUI_DIR."
fi

# Navigate to ComfyUI directory
cd "$COMFYUI_DIR"
echo "Changed directory to $COMFYUI_DIR"

# Update ComfyUI if it's a git repository
if [ -d ".git" ]; then
    echo "Updating ComfyUI from git repository..."
    git pull origin master --rebase
fi

# 2. Setup Python Virtual Environment
VENV_DIR="$COMFYUI_DIR/venv"
if [ ! -f "$VENV_DIR/bin/activate" ]; then # Check for activate script as a proxy for venv existence
    echo "Creating Python virtual environment in $VENV_DIR..."
    python3 -m venv "$VENV_DIR"
else
    echo "Python virtual environment already exists in $VENV_DIR."
fi

# Activate virtual environment
echo "Activating Python virtual environment..."
source "$VENV_DIR/bin/activate"

# 3. Install/Update Python Dependencies
echo "Installing/Updating Python dependencies from requirements.txt..."
pip install -r requirements.txt
# Consider adding a specific PyTorch version install here if you encounter CUDA issues, e.g.:
# pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
# You would need to determine your CUDA version (e.g., via nvidia-smi) and use the correct PyTorch wheel.

# 4. Download Models
echo "Checking and downloading models..."
MODELS_BASE_DIR="$COMFYUI_DIR/models"

# Flux.1 Dev FP8
DIFFUSION_MODELS_DIR="$MODELS_BASE_DIR/diffusion_models"
mkdir -p "$DIFFUSION_MODELS_DIR"
FLUX_MODEL_PATH="$DIFFUSION_MODELS_DIR/flux1-dev-fp8-e4m3fn.safetensors"
if [ ! -f "$FLUX_MODEL_PATH" ]; then
    echo "Downloading Flux.1 Dev FP8 model..."
    wget -O "$FLUX_MODEL_PATH" \
    https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8-e4m3fn.safetensors
else
    echo "Flux.1 Dev FP8 model already exists at $FLUX_MODEL_PATH."
fi

# VAE Model
VAE_MODELS_DIR="$MODELS_BASE_DIR/vae"
mkdir -p "$VAE_MODELS_DIR"
VAE_MODEL_PATH="$VAE_MODELS_DIR/ae.safetensors"
# WARNING: The following URL is the same as the Flux diffusion model.
# This is unusual for a VAE. Please verify if this is correct or provide the specific URL for your VAE.
VAE_URL="https://huggingface.co/Kijai/flux-fp8/resolve/main/flux1-dev-fp8-e4m3fn.safetensors"
if [ ! -f "$VAE_MODEL_PATH" ]; then
    echo "Downloading VAE model (URL: $VAE_URL)..."
    wget -O "$VAE_MODEL_PATH" "$VAE_URL"
else
    echo "VAE model already exists at $VAE_MODEL_PATH."
fi

# Upscale Models
UPSCALE_MODELS_DIR="$MODELS_BASE_DIR/upscale_models"
mkdir -p "$UPSCALE_MODELS_DIR"
CLEARREALITY_PATH="$UPSCALE_MODELS_DIR/4x-ClearRealityV1.pth"
if [ ! -f "$CLEARREALITY_PATH" ]; then
    echo "Downloading 4x-ClearRealityV1 upscale model..."
    wget -O "$CLEARREALITY_PATH" \
    https://huggingface.co/skbhadra/ClearRealityV1/resolve/main/4x-ClearRealityV1.pth
else
    echo "4x-ClearRealityV1 upscale model already exists at $CLEARREALITY_PATH."
fi

# Flux Controlnet (conditional on $flux_version variable)
# Ensure 'flux_version' is set in your environment if you need this.
if [ "$flux_version" == "true" ]; then
    FLUX_CONTROLNET_DIR="$MODELS_BASE_DIR/controlnet/FLUX.1/InstantX-FLUX1-Dev-Union"
    mkdir -p "$FLUX_CONTROLNET_DIR"
    FLUX_CONTROLNET_PATH="$FLUX_CONTROLNET_DIR/diffusion_pytorch_model.safetensors"
    if [ ! -f "$FLUX_CONTROLNET_PATH" ]; then
        echo "Downloading Flux Controlnet model..."
        wget -O "$FLUX_CONTROLNET_PATH" \
        https://huggingface.co/InstantX/FLUX.1-dev-Controlnet-Union/resolve/main/diffusion_pytorch_model.safetensors
    else
        echo "Flux Controlnet model already exists at $FLUX_CONTROLNET_PATH."
    fi
else
    echo "Skipping Flux Controlnet download (flux_version is not 'true')."
fi
echo "Finished checking/downloading models."

# 5. Patch ComfyUI main.py for legacy serialization
MAIN_PY_FILE="main.py" # We are already in COMFYUI_DIR
if [ -f "$MAIN_PY_FILE" ]; then
    if ! grep -qF "torch.serialization._legacy_serialization = True" "$MAIN_PY_FILE"; then
        echo "Patching $MAIN_PY_FILE to enable legacy serialization..."
        # Ensure 'import torch' is present
        if ! grep -qP "^\s*import\s+torch" "$MAIN_PY_FILE"; then
            echo "'import torch' not found in $MAIN_PY_FILE, adding it near the top."
            # Add 'import torch' after the first line (e.g., after shebang or initial comments)
            sed -i '1a import torch' "$MAIN_PY_FILE"
        fi
        # Add the legacy serialization line immediately after the first occurrence of 'import torch'
        sed -i "/^\s*import\s+torch/a torch.serialization._legacy_serialization = True" "$MAIN_PY_FILE"
        echo "Legacy serialization patch applied to $MAIN_PY_FILE."
    else
        echo "Legacy serialization patch already applied to $MAIN_PY_FILE."
    fi
else
    echo "ERROR: $MAIN_PY_FILE not found in $COMFYUI_DIR. Cannot apply patches."
    # Consider exiting if this patch is critical: exit 1
fi

# Workspace as main working directory for interactive shells (optional)
# This modifies .bashrc for future new shells, does not affect current script execution.
# echo "cd $NETWORK_VOLUME" >> ~/.bashrc

# 6. Start ComfyUI
echo "Starting ComfyUI from $PWD..."
python main.py --listen --port 3000# Uses python from the activated venv

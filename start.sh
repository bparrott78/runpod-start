#!/bin/bash
set -e
# Set the network volume path
NETWORK_VOLUME="/workspace"

cd /workspace

if [ -d "ComfyUI" ]; then
    cd ComfyUI

    # Check if venv directory exists
    if [ ! -d "venv" ]; then
        python3 -m venv venv
    fi
else
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    python3 -m venv venv
fi

# Always activate the venv
source venv/bin/activate

# Check if pip is working and dependencies are installed
if ! python -c "import yaml" &> /dev/null || [ ! -f "requirements.txt" ] || ! python -m pip show -q -r requirements.txt; then
    echo "Dependencies not found or venv not fully set up. Installing..."
    
    # Fix broken/missing pip
    python -m ensurepip --upgrade
    python -m pip install --upgrade pip
    
    # Install requirements and PyYAML, just in case
    python -m pip install -r requirements.txt
    python -m pip install PyYAML
else
    echo "All dependencies are already installed!"
fi
# Patch ComfyUI main.py for legacy serialization
echo "Patching ComfyUI main.py for legacy serialization"
MAIN_PY="workspace/ComfyUI/main.py"
if [ -f "$MAIN_PY" ]; then
    if ! grep -q "torch.serialization._legacy_serialization" "$MAIN_PY"; then
        echo "Patching main.py to enable legacy serialization"
        sed -i '2a import torch' "$MAIN_PY"
        sed -i '3a torch.serialization._legacy_serialization = True' "$MAIN_PY"
    fi
fi
# Check if NETWORK_VOLUME exists; if not, use root directory instead
if [ ! -d "$NETWORK_VOLUME" ]; then
    echo "NETWORK_VOLUME directory '$NETWORK_VOLUME' does not exist. You are NOT using a network volume. Setting NETWORK_VOLUME to '/' (root directory)."
    NETWORK_VOLUME="/"
    echo "NETWORK_VOLUME directory doesn't exist. Starting JupyterLab on root directory..."
    jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir=/ &
else
    echo "NETWORK_VOLUME directory exists. Starting JupyterLab..."
    jupyter-lab --ip=0.0.0.0 --allow-root --no-browser --NotebookApp.token='' --NotebookApp.password='' --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True --notebook-dir=/workspace &
fi
COMFYUI_DIR="$NETWORK_VOLUME/ComfyUI"
WORKFLOW_DIR="$NETWORK_VOLUME/ComfyUI/user/default/workflows"

# Set the target directory
CUSTOM_NODES_DIR="$NETWORK_VOLUME/ComfyUI/custom_nodes"

# Print diagnostic info
which python
python --version
python -c "import yaml; print('PyYAML version:', yaml.__version__)"

# Run ComfyUI
exec python main.py --port 3000 --listen

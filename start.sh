#!/bin/bash
set -e

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

# Print diagnostic info
which python
python --version
python -c "import yaml; print('PyYAML version:', yaml.__version__)"

# Run ComfyUI
exec python main.py

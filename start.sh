#!/bin/bash
set -e

cd /workspace

if [ -d "ComfyUI" ]; then
    cd ComfyUI
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

# Fix broken/missing pip
python -m ensurepip --upgrade
python -m pip install --upgrade pip

# Install requirements and PyYAML, just in case
python -m pip install -r requirements.txt
python -m pip install PyYAML

# Print diagnostic info
which python
python --version
python -c "import yaml; print('PyYAML version:', yaml.__version__)"

# Run ComfyUI
exec python main.py

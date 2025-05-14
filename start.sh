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

# Always activate venv and install/upgrade everything needed
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install PyYAML

echo "Python being used:"
which python

echo "Python version:"
python --version

echo "PyYAML version:"
python -c "import yaml; print(yaml.__version__)"

# Now run ComfyUI using *the venv Python*
exec python main.py

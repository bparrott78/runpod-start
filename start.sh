#!/bin/bash
set -e

cd /workspace

if [ -d "ComfyUI" ]; then
    cd ComfyUI
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        source venv/bin/activate
        pip install -r requirements.txt
    else
        source venv/bin/activate
    fi
else
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    python3 -m venv venv
    source venv/bin/activate
    pip install -r requirements.txt
fi

# Now run ComfyUI
exec python main.py

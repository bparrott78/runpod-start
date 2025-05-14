#!/bin/bash
set -e

cd /workspace

if [ -d "ComfyUI" ]; then
    cd ComfyUI
    if [ ! -d "venv" ]; then
        python3 -m venv venv
        source venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        pip install PyYAML
    else
        source venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        pip install PyYAML
    fi
else
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    python3 -m venv venv
    source venv/bin/activate
    pip install --upgrade pip
    pip install -r requirements.txt
    pip install PyYAML
fi

exec python main.py

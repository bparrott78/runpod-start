#!/bin/bash
set -e

cd /workspace

# Check for venv
if [ -d ".venv" ]; then
  echo "Activating existing venv"
  source .venv/bin/activate
else
  # Check for ComfyUI
  if [ ! -d "ComfyUI" ]; then
    echo "Cloning ComfyUI"
    git clone https://github.com/comfyanonymous/ComfyUI.git
  fi
  cd ComfyUI
  python3 -m venv ../.venv
  source ../.venv/bin/activate
  pip install -r requirements.txt
  cd ..
  echo "Setup complete."
  source .venv/bin/activate
fi

# Now run your main process, e.g., start ComfyUI, open shell, etc.
# exec python ComfyUI/main.py   # example
exec "$@"

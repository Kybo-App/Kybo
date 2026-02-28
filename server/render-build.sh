#!/usr/bin/env bash
# Render build script - fallback per ambienti senza nixpacks.toml.
# Uso normale: Render rileva automaticamente nixpacks.toml (preferito).
# Uso manuale: impostare come Build Command nel Render dashboard solo se
# nixpacks.toml non funziona: "bash server/render-build.sh"

set -e

echo "==> Installing system dependencies (Tesseract OCR + Italian)..."
apt-get update -qq
apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-ita \
    libgl1 \
    libglib2.0-0
rm -rf /var/lib/apt/lists/*

echo "==> Installing Python dependencies..."
pip install --upgrade pip --quiet
pip install -r requirements.txt --quiet

echo "==> Build complete!"

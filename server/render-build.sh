#!/usr/bin/env bash
# Render build script - installs system dependencies for Python buildpack

set -e

echo "Installing system dependencies..."
apt-get update
apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-ita \
    libgl1 \
    libglib2.0-0

echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Build complete!"

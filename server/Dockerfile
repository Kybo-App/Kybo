# Use newer, faster Python version
FROM python:3.11-slim

# Install system dependencies and Tesseract in a single layer to reduce image size
# Added --no-install-recommends to keep image small
# FIX: Replaced deprecated libgl1-mesa-glx with libgl1
RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    tesseract-ocr-ita \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy requirements first for cache optimization
COPY requirements.txt .

# Install python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Expose port
EXPOSE 8000

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
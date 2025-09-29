#!/bin/bash
set -e

# Single-stage build
echo "=== Building single-stage image ==="
docker build -t fastapi-single -f Dockerfile.single .

# Multi-stage build
echo "=== Building multi-stage image ==="
docker build -t fastapi-multi -f Dockerfile.multi .

# Порівняння розмірів
echo "=== Docker images ==="
docker images | grep fastapi

# Запуск контейнера (multi-stage для прикладу)
echo "=== Running container on http://localhost:8000 ==="
docker run -d --name fastapi-demo -p 8000:8000 fastapi-multi

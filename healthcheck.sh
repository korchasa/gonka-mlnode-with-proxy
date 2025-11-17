#!/bin/bash
# Check all required ports
curl -f http://localhost:5000/health || exit 1
echo "FastAPI health check passed"
curl -f http://localhost:8000/health || exit 1
echo "Uvicorn health check passed"
curl -f http://localhost:5050/health || exit 1
echo "Nginx 5050 health check passed"
curl -f http://localhost:8080/health || exit 1
echo "Nginx 8080 health check passed"
echo "All services healthy"

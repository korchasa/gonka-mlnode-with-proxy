# Unified ML for Gonka + Nginx Container

This container targets environments where only Docker deployment is available (RunPod, self-managed GPU nodes, etc.). It bundles the inference stack from `ghcr.io/product-science/mlnode:3.0.10` with Nginx-based reverse proxying in a single GPU-ready image.

Key characteristics:

- Base image remains `mlnode`, so all CUDA/Python tooling from upstream is available out of the box.
- We do **not** change the upstream entrypoint — all environment preparation (user `appuser`, `PYTHONPATH`, etc.) remains as in the original image.
- Nginx and uvicorn are started with a single line in `CMD`: Nginx runs in the background, uvicorn runs in the foreground.

## Usage

### Pre-built image (GHCR)

```bash
# latest version from the main branch
docker pull ghcr.io/korchasa/gonka-mlnode-with-proxy:latest

docker run --gpus all \
  -p 8080:8080 -p 5050:5050 \
  ghcr.io/korchasa/gonka-mlnode-with-proxy:latest
```

Port `8080` is used for uvicorn, `5050` for the inference endpoint served through Nginx. Nginx access/error logs stream to STDOUT/STDERR via symlinks, so hosting platforms capture them automatically. Health checks are available on all ports at `/health` endpoint.

## Ports

The container exposes two main ports through Nginx reverse proxy:

| Port | Service | Internal Target | Description |
|------|---------|-----------------|-------------|
| `8080` | Nginx → Uvicorn | `localhost:8000` | Main API endpoint, FastAPI application |
| `5050` | Nginx → Inference | `localhost:5000` | ML inference endpoint |

### Health Checks

Health checks are performed on all service ports:

| Port | Service | Health Check Endpoint |
|------|---------|----------------------|
| `5000` | Inference Service | `http://localhost:5000/health` |
| `8000` | Uvicorn/FastAPI | `http://localhost:8000/health` |
| `5050` | Nginx Inference Proxy | `http://localhost:5050/health` |
| `8080` | Nginx API Proxy | `http://localhost:8080/health` |

### Port Configuration

- **Port 8080**: Handles all FastAPI routes, including API endpoints, health checks, and application routes
- **Port 5050**: Dedicated to ML inference requests, routing to the model's internal server
- Both ports support versioned routes (`/v3.0.8/`) and backward-compatible routes (`/`)
- Nginx acts as a reverse proxy, forwarding requests to the appropriate internal services

### Logging

Nginx access logs include host and port information in the format: `host:port [timestamp] "request" status bytes_sent "user_agent"`
- Logs are streamed to STDOUT/STDERR for container orchestration platforms
- Both server blocks (ports 8080 and 5050) use the custom `main_with_port` log format

## Process layout

Container process tree is very simple:

- PID 1 — upstream entrypoint from `mlnode` (creates user, sets environment variables, etc.).
- Child — `bash -lc "nginx -g 'daemon off;' & ${UVICORN_CMD}"`.
- Within this command:
  - `nginx` runs in the background (`daemon off;`), logs go to STDOUT/STDERR via symlinks.
  - `uvicorn` runs in the foreground and is the main container process.

## Health Check

The container includes a built-in health check that monitors all service endpoints:
- **Interval**: 30 seconds
- **Timeout**: 10 seconds
- **Start period**: 5 seconds
- **Retries**: 3 attempts

Health check script validates connectivity to all four service ports using curl requests to `/health` endpoints.

## Environment Variables

| Variable     | Default                                          | Description                                    |
|--------------|--------------------------------------------------|------------------------------------------------|
| `UVICORN_CMD`| `uvicorn api.app:app --host=0.0.0.0 --port=8000` | Command executed inside the uvicorn service    |
| `NGINX_CMD`  | `nginx -g 'daemon off;'`                         | Command executed inside the nginx service      |
| `HF_HOME`    | `~/.cache`                                       | HuggingFace cache root (forwarded to uvicorn)  |

Example (custom uvicorn port and HuggingFace cache):

```bash
docker run --gpus all \
  -p 9000:9000 -p 5050:5050 \
  -e UVICORN_CMD="uvicorn api.app:app --host=0.0.0.0 --port=9000" \
  -e HF_HOME=/data/hf-cache \
  ghcr.io/korchasa/gonka-mlnode-with-proxy:latest
```

## Useful Links

- [Official Documentation: Multiple nodes](https://gonka.ai/host/multiple-nodes/)
- [Network Node API](https://gonka.ai/host/network-node-api/)
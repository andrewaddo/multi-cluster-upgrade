from fastapi import FastAPI
import os
import socket

app = FastAPI()

@app.get("/")
def read_root():
    return {
        "message": "GKE Multi-Cluster Upgrade Demo",
        "cluster": os.getenv("CLUSTER_NAME", "unknown"),
        "region": os.getenv("REGION", "us-central1"),
        "version": os.getenv("APP_VERSION", "v1.0.0"),
        "hostname": socket.gethostname()
    }

@app.get("/status")
def get_status():
    return read_root()

@app.get("/healthz")
def health_check():
    return {"status": "ok"}

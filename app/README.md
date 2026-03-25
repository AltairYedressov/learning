# Altair Yedressov — Portfolio App

A **two-tier portfolio application** showcasing Altair Yedressov's resume, skills, and experience.

---

## Architecture

```
┌─────────────┐       ┌────────────────────────┐       ┌──────────────────────────┐
│   Browser   │──────▶│  Frontend (Node.js)    │──────▶│  Backend API (Python)    │
│             │  :80  │  Express + EJS         │ :8000 │  FastAPI                 │
│             │◀──────│  Port 3000             │◀──────│  Serves resume JSON      │
└─────────────┘       └────────────────────────┘       └──────────────────────────┘
                        K8s LoadBalancer Service         K8s ClusterIP Service
                        (internet-facing)                (internal only)
```

| Layer      | Tech              | Responsibility                          |
|------------|-------------------|-----------------------------------------|
| Frontend   | Node.js + Express | Renders HTML via EJS, fetches from API  |
| Backend    | Python + FastAPI  | Serves resume data as JSON REST API     |
| Container  | Docker            | Each tier has its own Dockerfile         |
| Orchestration | Kubernetes (EKS) | Deployments, Services, health checks |
| Registry   | Amazon ECR        | Stores Docker images                    |
| AI         | Claude / Claude Code | AI-assisted development             |

---

## Project Structure

```
portfolio-app/
├── backend/
│   ├── main.py              # FastAPI application
│   ├── requirements.txt     # Python dependencies
│   └── Dockerfile           # Backend container image
├── frontend/
│   ├── src/
│   │   └── server.js        # Express server
│   ├── views/
│   │   ├── index.ejs        # Main portfolio page
│   │   └── error.ejs        # Error fallback page
│   ├── package.json         # Node.js dependencies
│   └── Dockerfile           # Frontend container image
├── k8s/
│   ├── 00-namespace.yaml    # Kubernetes namespace
│   ├── 01-backend.yaml      # Backend Deployment + ClusterIP Service
│   └── 02-frontend.yaml     # Frontend Deployment + LoadBalancer Service
└── README.md
```

---

## How This App Was Built

This application was created using **Claude AI** (Anthropic's AI assistant) with the following approach:

1. **Resume data** was extracted and structured into a Python FastAPI backend (`main.py`) that serves all profile, skills, experience, certifications, and project data as JSON via REST endpoints.

2. **A Node.js/Express frontend** (`server.js`) fetches data from the backend API and renders a visually striking portfolio page using EJS templates.

3. **Both tiers are containerized** with Docker — each has its own lightweight Dockerfile optimized for production.

4. **Kubernetes manifests** were written for deploying on AWS EKS, including health checks, resource limits, and proper inter-service networking.

5. **Insio** project experience was included in the projects section.

---

## Running Locally

### Prerequisites
- Docker & Docker Compose (or run each service standalone)
- Node.js 20+ and Python 3.12+

### Option A: Docker

```bash
# Build and run the backend
cd backend
docker build -t portfolio-api .
docker run -d -p 8000:8000 --name portfolio-api portfolio-api

# Build and run the frontend
cd ../frontend
docker build -t portfolio-frontend .
docker run -d -p 3000:3000 -e API_URL=http://host.docker.internal:8000 --name portfolio-frontend portfolio-frontend

# Open http://localhost:3000
```

### Option B: Without Docker

```bash
# Terminal 1 — Backend
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000

# Terminal 2 — Frontend
cd frontend
npm install
API_URL=http://localhost:8000 node src/server.js

# Open http://localhost:3000
```

---

## Deploying to AWS EKS

### Step 1: Create ECR Repositories

```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws ecr create-repository --repository-name portfolio-api --region $AWS_REGION
aws ecr create-repository --repository-name portfolio-frontend --region $AWS_REGION
```

### Step 2: Build & Push Docker Images

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push backend
cd backend
docker build -t portfolio-api .
docker tag portfolio-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/portfolio-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/portfolio-api:latest

# Build and push frontend
cd ../frontend
docker build -t portfolio-frontend .
docker tag portfolio-frontend:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/portfolio-frontend:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/portfolio-frontend:latest
```

### Step 3: Create EKS Cluster (if not existing)

```bash
eksctl create cluster \
  --name altair-portfolio \
  --region $AWS_REGION \
  --nodegroup-name workers \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 1 \
  --nodes-max 3 \
  --managed

# Verify
kubectl get nodes
```

### Step 4: Update K8s Manifests

Replace placeholders in `k8s/01-backend.yaml` and `k8s/02-frontend.yaml`:

```bash
sed -i "s/<AWS_ACCOUNT_ID>/$AWS_ACCOUNT_ID/g" k8s/01-backend.yaml k8s/02-frontend.yaml
sed -i "s/<REGION>/$AWS_REGION/g" k8s/01-backend.yaml k8s/02-frontend.yaml
```

### Step 5: Deploy to EKS

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-backend.yaml
kubectl apply -f k8s/02-frontend.yaml

# Watch rollout
kubectl -n portfolio rollout status deployment/portfolio-api
kubectl -n portfolio rollout status deployment/portfolio-frontend
```

### Step 6: Get External URL

```bash
kubectl -n portfolio get svc portfolio-frontend

# Wait for EXTERNAL-IP to populate, then open in browser
# Example: http://a1b2c3d4e5.elb.us-east-1.amazonaws.com
```

---

## API Endpoints

| Method | Path                | Description                 |
|--------|---------------------|-----------------------------|
| GET    | `/api/health`       | Health check                |
| GET    | `/api/profile`      | Profile info                |
| GET    | `/api/skills`       | Skills grouped by category  |
| GET    | `/api/experience`   | Work experience             |
| GET    | `/api/certifications` | Certifications            |
| GET    | `/api/projects`     | Projects                    |
| GET    | `/api/all`          | All data in one response    |

---

## Tech Stack

- **Frontend:** Node.js, Express, EJS
- **Backend:** Python, FastAPI, Uvicorn, Pydantic
- **Containers:** Docker
- **Orchestration:** Kubernetes (AWS EKS)
- **Registry:** Amazon ECR
- **AI Tools:** Claude, Claude Code

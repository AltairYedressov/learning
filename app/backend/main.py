"""
Altair Yedressov — Portfolio API (Python / FastAPI)
Serves resume data as JSON endpoints for the Node.js frontend.
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
import datetime

app = FastAPI(
    title="Altair Yedressov Portfolio API",
    description="Backend API serving resume & portfolio data",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Data Models ──────────────────────────────────────────────────────────────

class Skill(BaseModel):
    category: str
    items: List[str]

class Experience(BaseModel):
    title: str
    company: str
    period: str
    location: str
    highlights: List[str]

class Certification(BaseModel):
    name: str
    abbrev: str

class Project(BaseModel):
    name: str
    description: str
    tech: List[str]

class Profile(BaseModel):
    name: str
    title: str
    email: str
    phone: str
    location: str
    linkedin: str
    github: str
    summary: str

class HealthCheck(BaseModel):
    status: str
    service: str
    version: str
    timestamp: str

# ── Static Data (from resume) ───────────────────────────────────────────────

PROFILE = Profile(
    name="Altair Yedressov",
    title="Platform / DevOps / Cloud Engineer",
    email="altair.yedressov@gmail.com",
    phone="(914) 247-2930",
    location="New York, NY",
    linkedin="linkedin.com/in/altairyedressov",
    github="github.com/altair-dev",
    summary=(
        "Platform engineer with 5+ years operating production Kubernetes at scale — "
        "10+ EKS clusters, 20+ microservices, supporting 40+ engineers across "
        "The Home Depot and Ring (Amazon). I build self-service infrastructure: "
        "GitOps pipelines that cut release cycles from days to hours, Teleport-based "
        "access control that reduced engineer onboarding/offboarding from days to "
        "minutes, and observability that caught a critical checkout failure mid-Black "
        "Friday and prevented multi-million-dollar revenue loss. AWS, Terraform, "
        "CKA & CKAD certified. I sit with product teams — not separate from them."
    ),
)

SKILLS: List[Skill] = [
    Skill(category="Cloud & Infra", items=["AWS", "Azure", "GCP", "Terraform", "Helm", "Kubernetes", "Docker", "Linux", "Karpenter", "Rancher"]),
    Skill(category="CI/CD & GitOps", items=["GitHub Actions", "FluxCD", "ArgoCD", "Jenkins", "GitLab CI"]),
    Skill(category="Observability", items=["Prometheus", "Grafana", "Alertmanager", "OpenTelemetry", "EFK Stack", "CloudWatch", "Datadog"]),
    Skill(category="Security", items=["Teleport", "HashiCorp Vault", "IAM", "VPC Security", "Azure Key Vault", "mTLS", "Audit Logging"]),
    Skill(category="Data & Messaging", items=["Apache Kafka", "Amazon Kinesis", "PgBouncer", "RDS", "Aurora", "DocumentDB", "DynamoDB"]),
    Skill(category="AI & Dev Tools", items=["Claude", "Claude Code", "GitHub Copilot", "Cursor", "ChatGPT", "MCP", "AI Agents", "Prompt Engineering"]),
    Skill(category="Practices", items=["SLA/SLO", "Incident Response", "Jira", "Confluence", "API Design"]),
]

EXPERIENCE: List[Experience] = [
    Experience(
        title="Infrastructure / Platform Engineer",
        company="The Home Depot",
        period="Feb 2022 – Present",
        location="Hybrid",
        highlights=[
            "Own the platform serving 10+ EKS clusters and 20+ microservices — built self-service CI/CD that lets 40+ engineers ship to production without DevOps involvement, cutting release cycles from days to hours across Java, Node.js, and Python services",
            "Detected and resolved a critical checkout failure during Black Friday traffic using Prometheus, Grafana, and Alertmanager deployed via FluxCD — preventing potential multi-million-dollar revenue impact",
            "Deployed Teleport for centralized access control across AWS and Kubernetes — eliminated shared credentials, enabled per-session audit logging for SOC compliance",
            "Migrated from ArgoCD to FluxCD for a lighter, controller-based GitOps architecture — enforces continuous cluster reconciliation with Git",
            "Managed 10+ EKS clusters via Rancher with zero unplanned downtime — node autoscaling via Karpenter, resource quotas, rolling updates",
            "Created permission-boundary policies and automated IAM role provisioning using Terraform — adopted as team standard",
            "Provisioned databases (RDS/Aurora/DocumentDB) with Terraform and implemented cross-region backup strategies with sub-30-minute recovery objectives",
            "Standardized reusable Terraform module library across cloud deployments",
            "Migrated services from Azure (AKS, Blob Storage, SQL) and GCP (GKE, GCS) to AWS (EKS, S3, RDS, EC2)",
        ],
    ),
    Experience(
        title="Junior DevOps Engineer",
        company="Ring (Amazon)",
        period="Mar 2020 – Jan 2022",
        location="Remote",
        highlights=[
            "Containerized 8 legacy services with Docker and migrated to AWS EKS — cut infrastructure costs by ~$50K/year",
            "Built EFK centralized logging stack for 15+ microservices — reduced average developer debug time from hours to minutes",
            "Migrated event streaming pipelines from Apache Kafka to Amazon Kinesis with zero data loss",
            "Created reusable Terraform modules for IAM role provisioning and least-privilege policy management",
            "Partnered with 4 engineering teams to migrate from manual deploys to fully automated GitHub Actions pipelines",
            "Hardened network security via VPC segmentation, security group audits, and mTLS enforcement — passed first internal security review with zero critical findings",
            "Architected multi-region failover on AWS after identifying single-region risk",
        ],
    ),
]

CERTIFICATIONS: List[Certification] = [
    Certification(name="Certified Kubernetes Administrator", abbrev="CKA"),
    Certification(name="Certified Kubernetes Application Developer", abbrev="CKAD"),
    Certification(name="Terraform Associate (004)", abbrev="TF-004"),
    Certification(name="AWS Certified Solutions Architect – Associate", abbrev="AWS SAA"),
]

PROJECTS: List[Project] = [
    Project(
        name="This Portfolio App",
        description="Two-tier portfolio application with a Node.js frontend and Python FastAPI backend, containerized with Docker and deployed on AWS EKS via Kubernetes manifests. Built with Claude AI assistance.",
        tech=["Node.js", "Express", "Python", "FastAPI", "Docker", "Kubernetes", "EKS", "Claude AI"],
    ),
    Project(
        name="Insio",
        description="Contributed to Insio — a collaborative platform project leveraging modern cloud-native architecture and DevOps best practices for streamlined team workflows.",
        tech=["Cloud-Native", "DevOps", "CI/CD", "Kubernetes"],
    ),
]

# ── Endpoints ────────────────────────────────────────────────────────────────

@app.get("/api/health", response_model=HealthCheck)
def health():
    return HealthCheck(
        status="healthy",
        service="portfolio-api",
        version="1.0.0",
        timestamp=datetime.datetime.utcnow().isoformat(),
    )

@app.get("/api/profile", response_model=Profile)
def get_profile():
    return PROFILE

@app.get("/api/skills", response_model=List[Skill])
def get_skills():
    return SKILLS

@app.get("/api/experience", response_model=List[Experience])
def get_experience():
    return EXPERIENCE

@app.get("/api/certifications", response_model=List[Certification])
def get_certifications():
    return CERTIFICATIONS

@app.get("/api/projects", response_model=List[Project])
def get_projects():
    return PROJECTS

@app.get("/api/all")
def get_all():
    """Single endpoint returning all resume data."""
    return {
        "profile": PROFILE.dict(),
        "skills": [s.dict() for s in SKILLS],
        "experience": [e.dict() for e in EXPERIENCE],
        "certifications": [c.dict() for c in CERTIFICATIONS],
        "projects": [p.dict() for p in PROJECTS],
    }

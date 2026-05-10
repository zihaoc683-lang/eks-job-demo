# Enterprise-Grade EKS Governance & FinTech Delivery Platform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Platform: AWS](https://img.shields.io/badge/Platform-AWS-orange.svg)](https://aws.amazon.com/)
[![Kubernetes: 1.31](https://img.shields.io/badge/Kubernetes-1.31-blue.svg)](https://kubernetes.io/)

## 🚀 Executive Summary

This repository demonstrates a **fully-governed, resilient, and secure enterprise cloud infrastructure** based on AWS EKS. Designed specifically for highly-regulated sectors like **Financial Services (FinTech)** and **Telecommunications**, this project transcends basic Kubernetes deployment by integrating **Infrastructure as Code (IaC)**, **Policy-as-Code (PaC)**, and **Progressive Delivery** into a unified Governance framework.

### 🎯 Key Objectives:
- **Zero-Trust Security**: Implementing fine-grained identity management and network isolation.
- **Continuous Governance**: Automated policy enforcement to prevent configuration drift.
- **Resilient Operations**: Advanced rollout strategies to ensure 99.99% service availability.
- **Cost Efficiency**: Leveraging hybrid compute strategies (EC2 + Fargate).

---

## 🏗️ Architectural Overview

The architecture follows the **AWS Well-Architected Framework** principles:

### 1. Infrastructure Layer (IaC)
- **Terraform Modules**: Modularized VPC, EKS, RDS, and Redis clusters to ensure reusability and standardization across multiple regions.
- **Persistence Layer**: Decoupled stateful services using AWS RDS (MySQL) and ElastiCache (Redis) to ensure high availability and disaster recovery.

### 2. Governance & Security (DevSecOps)
- **Identity (IRSA)**: Leveraging OIDC for **IAM Roles for Service Accounts**, eliminating the need for static AWS Access Keys.
- **Policy-as-Code (Kyverno)**: Enforcing enterprise compliance at the admission control level (e.g., preventing root execution, ensuring resource quotas).
- **Secrets Management**: Integration with **AWS Secrets Manager** via **External Secrets Operator (ESO)** to maintain a single source of truth for sensitive data.
- **Network Segmentation**: Implementing **Kubernetes Network Policies** for micro-segmentation, shielding critical backend databases from frontend vulnerabilities.

### 3. Progressive Delivery (GitOps)
- **Argo Rollouts (Canary)**: Implementing traffic-based Canary deployments. This minimizes blast radius during updates by shifting traffic (10% -> 30% -> 100%) based on real-time health metrics.
- **Automated Rollbacks**: Integrated with monitoring to trigger instant reversion on failure detection.

---

## 🛠️ Tech Stack

| Domain | Tools |
| :--- | :--- |
| **Cloud Provider** | AWS (VPC, EKS, RDS, ElastiCache, S3, IAM) |
| **Infrastructure** | Terraform, Ansible |
| **Orchestration** | Kubernetes (EKS v1.31) |
| **Security/Compliance** | Kyverno, Trivy, Checkov, Kube-linter, NetPol |
| **CI/CD & GitOps** | Azure Pipelines, Argo Rollouts, Helm |
| **Observability** | Prometheus, Grafana, K8sGPT (AI-Driven Diagnostics) |
| **Machine Learning** | Taints/Tolerations for specialized GPU/AI Compute Pools |

---

## 📖 Operational Documentation

To explore the professional depth of this project, please refer to the following architectural and SRE guides:

- [Technical Merits: The "Why" behind the Architecture](./docs/08-technical-merits.md)
- [Operational Runbook: SRE Incident Response](./docs/07-incident-runbook.md)
- [Interview Prep: Architectural Decisions & Strategy](./docs/06-interview-prep.md)

---

## 📞 Contact & Engagement

Looking for a **DevOps/SRE Specialist** who understands more than just YAML? I am a Cloud Professional dedicated to building scalable, secure, and resilient platforms that drive business value.

**"Infrastructure is just code; Governance is the true differentiator."**

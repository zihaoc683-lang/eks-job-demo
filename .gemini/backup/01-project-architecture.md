# 🏗️ 專案架構與技術決策 (Project Architecture & Technical Merits)

本文件整合了本專案的基礎設施藍圖、DevSecOps 治理策略與各項技術選型的深度解析。目標在於展示一個具備生產級別 (Production-Ready) 的 EKS 雲端架構設計。

![EKS Architecture](../images/aws_eks_architecture_2d.png)

---

## 🌟 核心架構亮點 (Technical Merits)

### 1. 零信任與多層次安全防禦 (Defense-in-Depth)

| 防禦層 | 技術手段 | 實踐位置 |
| :--- | :--- | :--- |
| **基礎網路隔離** | 透過 VPC 將 Worker Nodes 放置於 Private Subnet，阻斷外部直接存取。 | [vpc.tf](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/vpc.tf) — `private_subnets` + `single_nat_gateway` |
| **K8s 網路微隔離** | 實作 Default Deny 原則，僅允許授權的 Pod 互相通訊。 | Kubernetes NetworkPolicy |
| **准入控制 (Kyverno)** | 在 API Server 階段攔截非授權映像檔與特權容器，從源頭斬斷漏洞。 | [k8s/07-kyverno-policy.yaml](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/k8s/07-kyverno-policy.yaml) |
| **左移資安 (Shift-Left)** | Trivy + GitHub Actions，在 CI 與 Runtime 階段雙重封殺已知漏洞 (CVE)。 | [.github/workflows/security-scan.yml](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/.github/workflows/security-scan.yml) |

---

### 2. 高可用性與雲端 API 整合 (HA & AWS API Integration)

#### 🔹 多可用區部署 (Multi-AZ)

底層 VPC 與 EKS 跨多個 AZ 部署，避免單一資料中心故障導致停機。

> **實踐位置**：[vpc.tf](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/vpc.tf) — `azs = slice(..., 0, 2)` 取前兩個可用區。

#### 🔹 IAM Roles for Service Accounts (IRSA)

本專案的安全核心。捨棄寬鬆的 Node Role，改用 OIDC 將 IAM 直接綁定至 K8s Service Account。實現「最小權限原則」，防止攻擊者透過受損 Pod 進行雲端資源的側向移動。

**深入解析：為什麼選擇 IRSA 而非傳統 Node IAM Role？**

| 特性 | 傳統 Node IAM Role | IRSA |
| :--- | :--- | :--- |
| **權限範圍** | **主機級別**：所有 Pod 共用同一權限集。 | **Pod 級別**：每個 Pod 獨立隔離。 |
| **最小權限** | **難以實現**：Pod A 需要 S3，Pod B 也會獲得。 | **完美實踐**：Pod A 拿 S3，Pod B 拿 EBS，互不干涉。 |
| **安全性** | **高風險**：任一 Pod 被攻破，攻擊者取得節點整體權限。 | **低風險**：權限僅侷限於該 Pod 專屬的 IAM Role。 |
| **身份驗證** | EC2 Metadata (IMDS)，容易被偽造。 | OIDC + AWS STS 臨時憑證，安全性更高。 |

> **關鍵價值**：透過 **EKS OIDC Provider** 實現細粒度隔離。確保 `ebs-csi-driver` 僅能操作磁碟而無法存取 S3 等敏感資源，符合金融級 (PCI-DSS) 資安稽核。

#### 🔹 彈性與負載平衡

結合 AWS ALB/NLB 與 Kubernetes HPA，透過 AWS Load Balancer Controller 自動化管理雲端網路資源。

#### 🔹 自動化儲存治理 (AWS EBS CSI)

自動化管理磁碟生命週期。並透過 `WaitForFirstConsumer` 延遲綁定技術，確保「磁碟跟隨 Pod」於同一可用區 (AZ) 建立，解決 EBS 跨區掛載失敗的硬傷。

| 層級 | 實踐位置 | 說明 |
| :--- | :--- | :--- |
| **基礎設施層** | [eks.tf](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/eks.tf) — `cluster_addons` | 啟用 `aws-ebs-csi-driver` 並透過 `ebs_csi_irsa_role` 配置 IRSA 授權。 |
| **應用定義層** | [k8s/01-storage.yaml](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/k8s/01-storage.yaml) | 定義 `StorageClass`，指定 `provisioner: ebs.csi.aws.com` + `WaitForFirstConsumer`。 |

---

### 3. 持續交付與 GitOps (Continuous Delivery)

| 能力 | 說明 | 實踐位置 |
| :--- | :--- | :--- |
| **唯一真相來源** | 透過 Argo CD 實現基礎設施狀態與 GitHub 儲存庫的強制同步。 | [k8s/08-argo-application.yaml](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/k8s/08-argo-application.yaml) |
| **配置偏移修復** | 當線上環境遭到人為篡改時，Argo CD 會在 3 分鐘內自動修復回 Git 上的原始設定。 | Argo CD 內建 Drift Detection |
| **漸進式交付** | 金絲雀發布 (Canary)，精準控制「爆炸半徑」，支援秒級回滾。 | [k8s/02-rollout.yaml](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/k8s/02-rollout.yaml) — `Rollout` + `canary` 策略 |

---

### 4. 可觀測性與監控 (Observability)

| 能力 | 說明 | 實踐位置 |
| :--- | :--- | :--- |
| **全方位監控 (Prometheus)** | 透過 Prometheus 自動收集 K8s 叢集與應用的效能指標 (Metrics)。 | `kube-prometheus-stack` (Helm Chart) |
| **視覺化儀表板 (Grafana)** | 提供預設的 K8s 監控面板，方便快速查看 CPU/Memory 使用率與系統瓶頸。 | [k8s/09-observability.yaml](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/k8s/09-observability.yaml) |

---

## 🛠️ 架構演進與技術選型 (Evolution & Choices)

在建置此專案時，我面臨了多種技術選擇，以下為最終選型的商業與技術考量：

### IaC 工具：Terraform vs CloudFormation

*   **選型決定**：Terraform
*   **深層考量點**：
    1.  **高開發效率 (HCL)**：相較於 CloudFormation 冗長的 JSON，HCL 提供強大的邏輯控制 (`for_each`)，程式碼更簡潔且易於維修。
    2.  **業界標準模組**：大量採用 `terraform-aws-modules` 認證模組，快速落實 AWS 最佳實踐並確保架構標準化。
    3.  **變更可預測性 (Planning)**：透過 `plan` 機制在執行前精準預視影響，搭配 `State Lock` 確保團隊協作安全性。
    4.  **全棧治理能力**：單一工具即可管理 AWS、Cloudflare 與 GitHub 等資源，展現跨平台架構治理的專業度。

### 持續交付：Argo CD vs Jenkins

*   **選型決定**：Argo CD (GitOps)
*   **考量點**：傳統的 Push-based CI/CD (如 Jenkins) 需要將 K8s 的高權限憑證存放在外部 CI 伺服器，安全風險極高。Argo CD 採用 Pull-based 模型，部署於叢集內部主動拉取 Git 配置，不僅解決了憑證外洩風險，也帶來了強大的自癒與配置修復能力。

### 原生部署工具：Kustomize vs Helm

*   **選型決定**：Kustomize (專案最終重構選用)
*   **考量點**：Helm 適合打包第三方程式庫 (如 Redis、Argo)，但對於內部微服務，Kustomize 的 Base & Overlays 架構更加輕量。無需編寫複雜的 Go Template，即可透過 Patch 優雅地管理環境差異。

    **實踐方式**：

    | 層級 | 路徑 | 用途 |
    | :--- | :--- | :--- |
    | **Base 層** | [k8s/base](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/k8s/base) | 存放核心的 `Deployment` 與 `Service`，作為所有環境的共同基石。 |
    | **Overlay 層** | [k8s/overlays](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/k8s/overlays) | `production` 目錄透過 `patches` 覆寫參數，實現「一套代碼，多環境運行」。 |

### 安全政策引擎：Kyverno vs OPA Gatekeeper

*   **選型決定**：Kyverno
*   **考量點**：OPA Gatekeeper 需要學習專屬的 Rego 語言，學習曲線陡峭。Kyverno 採用 K8s 原生的 YAML 格式編寫政策，維運團隊可快速上手，且其攔截與生成能力完美符合企業敏捷資安的需求。

---

## 🔒 合規性與進階治理 (Governance)

為因應嚴格的企業合規要求（例如：金融法規或 ISO 27001），本平台具備以下進階治理能力：

| 治理能力 | 說明 | 實踐位置 |
| :--- | :--- | :--- |
| **作業系統加固 (Ansible)** | 透過 Ansible 在 EC2 啟動時自動關閉危險端口、提升網路參數，並確保 SSM Agent 啟用以供無密碼安全審計。 | [ansible/node-hardening.yml](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/ansible/node-hardening.yml) |
| **IaC 靜態安全掃描 (Checkov)** | 在 GitHub Actions 中強制執行 Checkov，防止提交「開啟 Public Access 的 S3」或「未加密的 EBS」等高危險代碼。 | [security-scan.yml](file:///c:/Users/kilok/Desktop/%E7%B7%AF%E8%82%B2/eks-project/day5-job-demo/.github/workflows/security-scan.yml) |
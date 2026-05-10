# 🏗️ EKS 雲端架構與技術決策 (01)

本專案不僅是一個 EKS 叢集，更是一個完整的**平台工程 (Platform Engineering) 解決方案**。架構設計核心圍繞著「安全性」、「自癒力」與「可自動化」三大核心指標。

---

## 🏛️ 架構全景圖 (High-Level Architecture)

### 1. 核心基礎設施 (The Core)
*   **雲端環境**：AWS (VPC, EKS, IAM, EBS)
*   **計算資源**：EKS Managed Node Groups (基於 `t3.small` 的 Auto Scaling Group)。
*   **網路架構**：
    *   **Public Subnets**：部署 AWS Load Balancers (NLB/ALB)。
    *   **Private Subnets**：部署 EKS 節點與應用程式，確保不直接曝露於 Internet。
    *   **NAT Gateway**：讓 Private Subnets 內的節點能安全地拉取外部 Docker Image。

### 2. 零信任安全防禦體系 (Zero Trust Security Stack)

本架構遵循「永不信任，始終驗證」的零信任原則，建立多層次的防護網：

#### 🔹 身分即邊界：IAM Roles for Service Accounts (IRSA)
本專案的安全核心。捨棄寬鬆的 Node Role，改用 OIDC 將 IAM 直接綁定至 K8s Service Account。這實現了**身分基礎的最小權限原則 (Identity-based Least Privilege)**，即使攻擊者攻破單一 Pod，也無法獲取其他雲端資源的存取權，大幅限縮了「爆炸半徑」。

#### 🔹 持續性准入驗證：政策治理 (Kyverno)
*   **零信任稽核**：利用 K8s Admission Webhook 在資源建立前進行 100% 攔截驗證。
*   **強制合規**：透過代碼化的政策 (Policy as Code)，強制執行資安準則，不依賴人為判斷。

#### 🔹 映像檔安全 (Trivy Operator)
*   **Runtime Scanning**：自動掃描叢集中運行的所有 Pod，產出 CVE 漏洞報告，實現持續性資安監控。

### 3. 資料持久化 (Persistence)
*   **AWS EBS CSI Driver**：透過 Dynamic Provisioning 自動化管理雲端硬碟。
*   **StorageClass 設計**：採用 `WaitForFirstConsumer` 策略，解決跨可用區 (Multi-AZ) 掛載失敗的經典問題。

| 層級 | 實踐位置 | 說明 |
| :--- | :--- | :--- |
| **基礎設施層** | [eks.tf](eks.tf) — `cluster_addons` | 啟用 `aws-ebs-csi-driver` 並透過 `ebs_csi_irsa_role` 配置 IRSA 授權。 |
| **應用定義層** | [k8s/01-storage.yaml](k8s/01-storage.yaml) | 定義 `StorageClass`，指定 `provisioner: ebs.csi.aws.com` + `WaitForFirstConsumer`。 |

### 4. 可觀測性與監控 (Observability)

| 能力 | 說明 | 實踐位置 |
| :--- | :--- | :--- |
| **全方位監控 (Prometheus)** | 透過 Prometheus 自動收集 K8s 叢集與應用的效能指標 (Metrics)。 | `kube-prometheus-stack` (Helm Chart) |
| **視覺化儀表板 (Grafana)** | 提供預設的 K8s 監控面板，方便快速查看 CPU/Memory 使用率與系統瓶頸。 | [k8s/09-observability.yaml](k8s/09-observability.yaml) |

---

## 📈 SRE 指標達成策略 (MTTR / RTO / RPO)

本架構在設計時，特別針對 SRE 三大核心指標進行了優化，確保系統具備生產級別的彈性：

### 📊 SRE 服務等級指標預估 (SLA Estimates)

| 指標 | 預估時間 | 實踐技術支撐 |
| :--- | :--- | :--- |
| **RTO** (復原時間) | **15 - 20 分鐘** | Terraform 自動化基礎設施重建 (12m) + Bootstrap 平台引導 (3m)。 |
| **RPO** (數據丟失點) | **< 1 分鐘** | AWS EBS 持久化儲存 (近乎即時) + GitOps 唯一真相來源 (0 延遲)。 |
| **MTTR** (平均修復時間) | **30 秒 - 5 分鐘** | K8s Pod 自癒 (30s) + Argo CD 自動偏移修復 (3m) + SRE Runbook 標準化操作。 |

---

## 🛠️ 開發與維運流程 (DevOps Workflow)

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
    | **Base 層** | [k8s/base](k8s/base) | 存放核心的 `Deployment` 與 `Service`，作為所有環境的共同基石。 |
    | **Overlay 層** | [k8s/overlays](k8s/overlays) | `production` 目錄透過 `patches` 覆寫參數，實現「一套代碼，多環境運行」。 |

### 安全政策引擎：Kyverno vs OPA Gatekeeper

*   **選型決定**：Kyverno
*   **考量點**：OPA Gatekeeper 需要學習專屬的 Rego 語言，學習曲線陡峭。Kyverno 採用 K8s 原生的 YAML 格式編寫政策，維運團隊可快速上手，且其攔截與生成能力完美符合企業敏捷資安的需求。

---

## 🔒 合規性與進階治理 (Governance)

為因應嚴格的企業合規要求（例如：金融法規或 ISO 27001），本平台具備以下進階治理能力：

| 治理能力 | 說明 | 實踐位置 |
| :--- | :--- | :--- |
| **資源消耗限制 (Quotas)** | 透過 Kustomize Patch 強制所有 Pod 必須定義 Resource Requests/Limits，防止鄰居干擾。 | [k8s/base/deployment.yaml](k8s/base/deployment.yaml) |
| **節點親和性 (Affinity)** | 確保關鍵服務部署於指定的 Instance Types。 | [eks.tf](eks.tf) (`labels`) |
| **事件追蹤 (Audit)** | 透過 K8s Events 追蹤所有變更，並與 Prometheus Alertmanager 整合。 | `monitoring` namespace |
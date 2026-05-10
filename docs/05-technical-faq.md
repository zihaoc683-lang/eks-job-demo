# 💡 技術架構常見問題與決策解析 (Technical FAQ)

本文件收錄了本專案在設計與建置過程中的關鍵技術決策、架構考量以及針對複雜工程問題的解決方案。旨在提供深度技術解析，說明「為什麼」選擇特定的架構與工具。

---

## 🏗️ 架構設計考量 (Design Rationale)

在建置生產級別的 K8s 平台時，架構師通常需要權衡安全性、可維護性與成本。以下為本專案的核心應對策略：

### 1. 基礎設施自動化與職責邊界 (IaC & Automation)
*   **技術挑戰**：如何在大規模環境中管理雲端資源與作業系統配置？
*   **解決方案**：
    *   **Terraform 模組化治理**：將網路 (VPC)、運算 (EKS) 職責拆分，確保狀態機 (State Machine) 的獨立性，降低誤刪風險。
    *   **IaC 的三層職責模型**：清晰定義出 **Terraform (雲端資源基礎)**、**Ansible (OS 基準線加固)**、**Kubernetes (容器編排)** 的職責劃分。

### 2. CI/CD 與 GitOps 演進
*   **技術挑戰**：如何解決傳統 CI 伺服器的高權限憑證風險？
*   **解決方案**：
    *   **GitOps 典範轉移**：捨棄傳統的 Push 模式，改用 Argo CD 的 Pull 模式。這不僅解決了憑證外洩問題，更帶來了自動化配置偏移偵測 (Drift Detection)。
    *   **流量精確控制 (Canary)**：使用 Argo Rollouts 實現漸進式交付，將新版本上線的「爆炸半徑 (Blast Radius)」降到最低，並具備秒級自動回滾能力。

### 3. 多層次資安防禦 (Security-in-Depth)
*   **技術挑戰**：如何實踐零信任 (Zero Trust) 架構？
*   **解決方案**：
    *   **身分即邊界 (IRSA)**：廢除廣泛的 Node 權限，為每個 Pod 分配最小權限的 IAM 身分。
    *   **准入控制 (Kyverno)**：在 K8s API Server 層級強制執行資安政策 (Policy as Code)，防止任何不合規的資源進入叢集。
    *   **內網隔離 (NetworkPolicy)**：實作 Default Deny，僅放行必要流量，阻斷潛在的側向移動攻擊。

### 4. SRE 穩定性與災難復原
*   **技術挑戰**：如何定義並達成 RTO/RPO 目標？
*   **解決方案**：
    *   **三層復原策略**：整合 Terraform (基礎設施)、Argo CD (應用配置) 與 Velero (數據快照)，確保在極端災難下能於 20 分鐘內重建全棧環境。
    *   **標準化 Runbook**：建立高度結構化的故障排查 SOP，將 MTTR 降至最低。

---

## ❓ 常見技術問答

### Q1: 為什麼不直接在 Terraform 裡安裝所有 K8s 組件？
**A**: 這是為了「解耦」。Terraform 應該專注於生命週期較長的雲端資源；而 K8s 內的組件生命週期較短且更新頻繁，交由 Helm 或 Argo CD 管理能提供更好的靈活性與版本控制。

### Q2: 在生產環境中，如何平衡 Spot Instance 的成本與穩定性？
**A**: 核心服務應部署於 On-Demand 節點或橫跨多個可用區 (AZ) 的 Spot Instance。本專案透過 ASG 的多實例類型策略與 `max_size` 限制，在極大化成本效益的同時確保服務可用性。

### Q3: 為什麼選擇 Kyverno 而不是 OPA Gatekeeper？
**A**: Kyverno 採用 K8s 原生的 YAML 格式，無需學習 Rego 語言，這大幅降低了維運團隊的門檻，且在「政策生成 (Generate)」與「變更 (Mutate)」能力上更加出色。

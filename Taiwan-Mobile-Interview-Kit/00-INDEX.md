# 台灣大哥大面試攻略：導覽索引 (Taiwan Mobile Interview Kit)

本資料夾是專為「I97 Kubernetes 平台工程師」職缺準備的技術與管理展示套件。

## 📂 文件目錄與對應職缺要求

### 1. [面試主策略 (INTERVIEW_STRATEGY.md)](./INTERVIEW_STRATEGY.md)
- **用途**: 面試前的自我複習、QA 準備。
- **核心**: 建立「精英工程師」的技術視野與態度。

### 2. [端到端交付流程 (DELIVERY_WORKFLOW.md)](./DELIVERY_WORKFLOW.md)
- **對應職缺**: 工作內容 1, 2, 4 (交付流程、可控發布、回滾)。
- **技術點**: Argo Rollouts (Canary), GitHub Actions CI。

### 3. [平台治理與標準化 (PLATFORM_GOVERNANCE.md)](./PLATFORM_GOVERNANCE.md)
- **對應職缺**: 工作內容 3, 5 (模板化、權限控管、治理)。
- **技術點**: Helm Templates, Kyverno (Policy as Code), IaC (Terraform)。

### 4. [故障排除與 SOP (SOP_MTTR_RUNBOOK.md)](./SOP_MTTR_RUNBOOK.md)
- **對應職缺**: 工作內容 6, 7 (故障排除、MTTR、Runbook/SOP)。
- **案例**: EKS 刪除死結 (RCA 根因分析) 與上線檢核表。

### 5. [Helm 標準化策略 (HELM_STRATEGY.md)](./HELM_STRATEGY.md)
- **對應職缺**: 平台標準化與開發者體驗。
- **重點**: 說明如何抽象化複雜 K8s 資源，讓開發團隊更易於上手。

---

## 🛠️ 輔助技術檔案 (位於專案其他位置)
- **觀測性實作**: `k8s/12-monitoring.yaml` (ServiceMonitor & Alerts)
- **安全掃描實作**: `.github/workflows/security-scan.yml` (Trivy Scan)
- **防止死結機制**: `cleanup.tf` & `eks.tf` 中的 `depends_on` 邏輯

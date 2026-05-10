# 台灣大哥大面試專屬：EKS 平台工程 Demo 攻略

本攻略針對「I97 Kubernetes 平台工程師」職缺量身打造。台灣大的文化強調「從攻城師升級為精英」，因此 Demo 的核心要環繞在 **自動化 (Automation)**、**治理 (Governance)** 與 **穩定性 (Stability)**。

---

## 一、 Demo 演示順序 (The "Elite" Flow)

建議按照以下順序演示，由底層到應用層，展現結構化思維。

### 1. 基礎設施自動化與穩定性 (IaC & Stability)
*   **檔案**：`vpc.tf`, `eks.tf`, `cleanup.tf`
*   **亮點**：強調 **「防止死結 (Deadlock Prevention)」**。
*   **關鍵詞**：DependencyViolation, ENI Recovery, Time Sleep.
*   **話術**： 「在平台工程中，『好拆』跟『好裝』同樣重要。我特別設計了清理邏輯，確保在刪除 VPC 前，所有 EKS 殘留 ENI 都已釋放，這能大幅降低 MTTR 並實現完全自動化的環境生命週期管理。」

### 2. 平台治理與標準化 (Governance)
*   **檔案**：`k8s/07-kyverno-policy.yaml`, `k8s/08-resource-governance.yaml`
*   **亮點**： **Policy as Code**。
*   **關鍵詞**：Kyverno, Admission Control, Resource Quota.
*   **話術**： 「台灣大的 IT 規模很大，人工審核部署是不可能的。我導入了 Kyverno 政策，強制要求所有 Pod 必須定義 Resource Limits，這就是我如何透過『技術手段』而非『口頭要求』來推動平台標準化。」

### 3. 進階交付與發布策略 (Modern Delivery)
*   **檔案**：`k8s/02-rollout.yaml`
*   **亮點**： **Argo Rollouts (Canary Release)**。
*   **關鍵詞**：Canary, Analysis, Rollback.
*   **話術**： 「我實作了金絲雀發布流程。透過 20% 的流量分發與人工審核點，我們能確保程式碼變更在可控範圍內，並能在發現異常時快速回滾，降低變更風險。」

### 4. 觀測性與安全供應鏈 (Observability & Security)
*   **檔案**：`k8s/12-monitoring.yaml`, `.github/workflows/security-scan.yml`
*   **亮點**： **指標量化與映像掃描**。
*   **關鍵詞**：ServiceMonitor, Trivy, CVE Scanning.
*   **話術**： 「我將安全左移 (Shift Left)，在 CI 階段就使用 Trivy 掃描 IaC 與映像檔漏洞。同時透過 ServiceMonitor 定義關鍵指標，將交付品質數據化，這符合台灣大對稽核與品質的嚴格要求。」

---

## 二、 必備問題與回答建議 (Q&A)

### Q1: 你如何處理 K8s 部署過程中的故障排除 (Troubleshooting)？
*   **回答思維**：展示「跨層分析」能力。
*   **建議回答**： 「我會從三層進行分析：首先是應用層 (`kubectl logs`, `events`)，檢查是否為程式碼或配置錯誤；其次是網路層，確認 Security Group 或 Network Policy 是否阻斷通訊；最後是平台層，確認 Node 狀態或 CNI (ENI) 是否達到上限。我也會利用 Prometheus 指標觀察錯誤率變化，推動改善閉環。」

### Q2: 對於「環境漂移 (Environment Drift)」你有什麼看法？如何解決？
*   **回答思維**：強調 GitOps。
*   **建議回答**： 「環境漂移是手動操作的產物。我傾向使用宣告式部署。透過 Terraform 維護基礎設施，並計畫導入 Argo CD (GitOps) 讓 Git 成為唯一的真實來源 (Single Source of Truth)。一旦發生手動變更，系統會自動偵測並還原，確保環境一致性。」

### Q3: 台灣大 IT 強調團隊合作與溝通，你如何與開發團隊協作？
*   **回答思維**：強調「提升開發者體驗」。
*   **建議回答**： 「我認為平台工程師的角色是提供『鋪好的路 (Paved Road)』。我會透過 Helm 模板化複雜的 K8s 物件，讓開發者只需填寫少數參數即可部署，並透過 Runbook 與 SOP 將經驗制度化，降低團隊對特定個人的依賴。」

### Q4: 如果 EKS 刪除時卡住了，你會怎麼處理？ (考你剛才修好的那個點)
*   **回答思維**：展示你對 AWS 與 K8s 整合的底層理解。
*   **建議回答**： 「這通常是因為 K8s 產生的 ELB 或 ENI 尚未釋放，導致 VPC 安全群組或子網無法刪除。我會在 Console 檢查掛載的 ENI，或是在 Terraform 中像我專案中那樣加入 `time_sleep` 延遲與 `kubectl` 清理腳本來自動化解決。」

---

## 三、 給 CIO 隊長的加分小技巧
*   **展現「精英」態度**：不要只說「我用了這個工具」，要說「我為什麼選擇這個工具來解決業務痛點」。
*   **提及「可規模化」**：大型電信公司喜歡這個詞。多提到你的設計如何支持「大量應用程式同時部署」。
*   **強調「安全性」**：電信業對憑證、密鑰管理與權限控管 (RBAC) 非常敏感。

祝你面試順利！你現在的專案深度絕對具備「攻城精英」的水準！

# 台灣大哥大：端到端交付流程與發布策略 (Delivery Workflow)

本文件定義了應用程式從程式碼變更到生產環境的標準化路徑，旨在實現「可控發布」與「快速回滾」。

## 1. 交付流水線 (CI/CD Pipeline)
- **版本控制**: 基於 Git GitFlow 模式，所有變更必須經過 Pull Request (PR) 審核。
- **自動化稽核**: 透過 `.github/workflows/security-scan.yml` 在 CI 階段強制進行 Trivy 映像檔掃描，符合職缺中「可追溯稽核」的要求。
- **Artifact 管理**: 映像檔標籤 (Tag) 嚴格對應 Git Commit SHA，確保環境可追溯性。

## 2. 可控發布策略 (Controlled Release)
我們採用 **Argo Rollouts (Canary)** 作為標準發布模式：
- **初始部署 (20%)**: 僅引流少量流量至新版本，並在背景監控指標。
- **人工審批點 (Promotion)**：在 `k8s/02-rollout.yaml` 中設置 `pause`，由維運或 QA 團隊進行驗證，降低變更風險。
- **全線上線 (100%)**: 驗證無誤後完成全量發布。

## 3. 快速回滾機制 (Fast Rollback)
- **指令**: `kubectl argo rollouts undo ecommerce-backend`
- **時機**: 當監控指標 (如 `k8s/12-monitoring.yaml` 中的錯誤率告警) 觸發時，系統支援一鍵秒級回滾至前一穩定版本，將 MTTR 降至最低。

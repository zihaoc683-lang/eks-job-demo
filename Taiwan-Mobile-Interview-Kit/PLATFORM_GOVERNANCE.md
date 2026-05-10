# 台灣大哥大：平台標準化與治理機制 (Platform Governance)

本文件說明如何建立可規模化的部署管理模式，並降低人工操作帶來的安全風險。

## 1. 基礎設施治理 (IaC Governance)
- **環境一致性**: 透過 Terraform (`eks.tf`, `vpc.tf`) 將基礎設施「版本化」。
- **防範環境漂移**: 嚴禁在 AWS Console 手動變更資源。所有資源必須通過 Terraform Plan/Apply 部署，確保環境與代碼同步。

## 2. 應用程式模板化 (Templating)
- **Helm 統一範本**: 使用 `helm-charts/ecommerce-app` 作為公司內部標準。開發團隊只需傳入應用參數，其餘「安全性設定」、「資源限制 (Quota)」皆由平台團隊在模板中鎖定。
- **好處**: 提升開發者體驗 (Developer Experience)，開發者無需成為 K8s 專家也能安全部署。

## 3. 安全與密鑰治理 (Secrets & Policy)
- **Policy as Code**: 使用 `k8s/07-kyverno-policy.yaml` 實作 Admission Control。拒絕不符合公司規範 (如未設 Limits 或使用 root 使用者) 的 Pod 入場。
- **密鑰管理**: 專案結構中預留 `k8s/09-external-secrets-mock.yaml`，展示未來對接 AWS Secrets Manager 的治理能力。

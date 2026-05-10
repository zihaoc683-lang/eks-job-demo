# 平台模板化策略 (Helm Standardization)

## 設計思維
對應「台灣大哥大 - Kubernetes 平台工程師」職缺中提到的「推動平台標準化與模板化」。
本專案透過 Helm 將複雜的 K8s 資源抽象化，提供給開發團隊一個簡單、可預測的部署介面。

## 1. 基礎模板 (Base Template)
- **ecommerce-app**: 作為公司內部的「標準應用程式模板」。
- 包含統一的 Liveness/Readiness Probe 規範。
- 內建符合安全性規範的 SecurityContext (Non-root user)。

## 2. 環境配置分離 (Values-driven)
- 透過不同的 `values.yaml` (e.g., `values-prod.yaml`, `values-dev.yaml`) 消除「環境漂移 (Environment Drift)」風險。
- 開發者僅需填寫鏡像名稱與副本數，其餘網路與資源限制 (Resource Quotas) 由平台團隊維護。

## 3. 最佳實踐
- **版本控管**: Chart 檔案隨 Git 進行版本管理，支援快速回滾。
- **可重複利用性**: 透過參數化設計，單一 Chart 即可支持所有 Stateless 服務。

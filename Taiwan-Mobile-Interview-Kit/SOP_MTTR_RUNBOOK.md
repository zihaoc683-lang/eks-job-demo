# 台灣大哥大：故障排除 SOP 與 MTTR 優化 (SOP & Runbook)

本文件將成功經驗制度化，旨在降低個人依賴，提升團隊排障效率。

## 1. 案例分析：EKS 資源刪除死結 (Root Cause Analysis)
- **問題描述**: 執行 `terraform destroy` 時頻繁發生 `DependencyViolation` 導致 VPC 無法刪除。
- **根因分析 (RCA)**: K8s 產生的 LoadBalancer 與 ENI 尚未釋放，導致 VPC 安全群組被鎖定。
- **自動化對策**: 實作 `cleanup.tf` 中的 `time_sleep` 與 `null_resource` 腳本，將排障經驗「代碼化」。
- **成果**: MTTR 從手動排障的 20 分鐘降至 1 分鐘內全自動化完成。

## 2. 應用程式上線檢核表 (Go-Live Checklist)
在每次新服務上線前，必須通過以下稽核：
- [ ] 映像檔已通過 Trivy 漏洞掃描 (Security Check)。
- [ ] 已定義 Resource Requests & Limits (Governance Check)。
- [ ] 已關聯 ServiceMonitor 並在 Grafana 出圖 (Observability Check)。
- [ ] 已實作 Liveness/Readiness Probe (Stability Check)。

## 3. 日常排障 Runbook
1. **第一步**：檢查 Prometheus Alertmanager 告警看板。
2. **第二步**：執行 `kubectl get pod` 觀察狀態 (CrashLoopBackOff / Pending)。
3. **第三步**：若為 Pending，檢查 `kubectl describe` 是否為 EBS 掛載問題或資源不足。
4. **第四步**：若為網路問題，執行 `kubectl get ep` 確認 Service Discovery 狀態。

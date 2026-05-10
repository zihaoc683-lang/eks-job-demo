# SRE 事件應變應急手冊 (Incident Response Runbook)
# 所屬專案：EKS Ecommerce Elite Platform

## 📖 簡介
本文件為本專案的標準作業程序 (SOP)，旨在指導維運人員 (SRE) 在發生緊急故障時，能以最短時間 (Minimize MTTR) 恢復系統服務。

---

## 🚨 故障情境 A：大規模 Pod 進入 CrashLoopBackOff/Error
**適用場景**：新版本佈署後發生程式崩潰，或連線資料庫失敗。

### 1. 快速診斷
```bash
# 查看異常 Pod
kubectl get pods -n default | grep -E 'CrashLoop|Error'

# 獲取 AI 修復建議 (AIOps 介入)
k8sgpt analyze --namespace default --explain
```
### 2. 應變動作
*   **情況 1：代碼 Bug** ➔ 執行 Argo Rollouts 一鍵回滾。
    ```bash
    kubectl argo rollouts undo ecommerce-backend
    ```
*   **情況 2：資料庫連線失敗** ➔ 檢查 `database.tf` 設定的 Security Group 規則。

---

## 🚨 故障情境 B：叢集節點資源耗盡 (Memory Pressure / OOM)
**適用場景**：突發流量導致 Node 記憶體不足，Pod 不斷被 Evicted。

### 1. 快速診斷
*   檢查 Grafana 的 「Node Resources」看板。
*   檢查是否有 Pod 違反了 `08-resource-governance.yaml` 的 Quota 設定。

### 2. 應變動作
*   **擴容**：手動調整 Terraform 中的 `max_size` 並執行 `apply`。
*   **限流**：檢查 Ingress 是否需要限制併發連線數。

---

## 🚨 故障情境 C：敏感資料外洩疑慮
**適用場景**：發現 AWS 密鑰疑似洩漏。

### 1. 應變動作
1. 立即於 AWS Secrets Manager 進行 **Secret Rotation (輪轉)**。
2. 由於我們導入了 **External Secrets Operator (ESO)**，系統會在一小時內自動同步新密碼，無需重啟服務。

---

## 📊 服務水準目標 (SLO) 承諾
本架構旨在達成以下金融級承諾：
- **服務可用性 (Availability)**: 99.95% (每月停機時間不超過 22 分鐘)。
- **平均回復時間 (MTTR)**: 小於 15 分鐘。
- **變更失敗率 (CFR)**: 小於 5% (透過金絲雀佈署達成)。

---
 
## 🛠️ SRE 事後分析報告模板 (Post-Mortem Template)
*當 P0 事件修復後，必須在 24 小時內完成此報告，以驅動系統優化。*

### 1. 事件概覽
- **事故名稱**：(例：訂單系統 API 回傳 500 異常)
- **發生日期**：YYYY-MM-DD
- **影響範圍**：全站電商流量、影響約 15% 用戶
- **恢復時間 (MTTR)**：45 分鐘

### 2. 故障現象與根因分析 (RCA)
- **現象**：Prometheus 告警顯示 Http 5xx 突增，Pod 出現 OOMKilled。
- **根因**：新版本代碼未配置 Resource Limit，導致突發流量下記憶體洩漏。

### 3. 恢復過程
- **偵測 (Detection)**：Slack 機器人推播告警。
- **處理 (Action)**：執行 `kubectl argo rollouts abort` 緊急回滾至上一穩定版本。
- **確認 (Verification)**：恢復正常流量，SLO 指標回歸預算內。

### 4. 預防措施 (Action Items)
- `[ ]` **技術優化**：在 Kyverno 加入強制 Resource Limit 校驗（已完成情境五演練）。
- `[ ]` **監控優化**：增加特定 Pod 記憶體攀升斜率的預警告警。
- `[ ]` **制度優化**：更新上線檢核表 (Checklist)。

---

**本文件由 SRE 團隊維修。請勿進行手動非正規變更。**

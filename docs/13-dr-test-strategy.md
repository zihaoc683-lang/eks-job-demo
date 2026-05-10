# 災難復原演練計畫 (Disaster Recovery Game Day Strategy)
# 所屬專案：EKS Ecommerce Elite Platform

## 📖 簡介
在金融保險業中，災難復原 (DR) 不能只是「備份」，必須經過「演練」驗證。本文件定義了如何進行週期性的 **Game Day (故障演習)**，以確保在極端情況下（如 AWS Region 級別故障）仍能維持營運。

---

## 🎯 1. 演練目標 (Objectives)
- 驗證 **RTO (復原時間目標)**：目標在 1 小時內恢復核心交易。
- 驗證 **RPO (復原點目標)**：目標資料遺失量小於 15 分鐘。
- 測試 **Velero** 於異地 Region 恢復 Kubernetes 資源的正確性。
- 測試團隊對 **SRE Runbook** 的熟悉程度。

---

## 🛠️ 2. 演練情境：AWS 東京區域 (ap-northeast-1) 全面失效
**模擬操作**：
1.  停止所有 ap-northeast-1 的 EKS 工作負載。
2.  模擬 RDS 故障。

---

## 📋 3. 標準復原流程 (Execution Plan)

### 第一階段：基礎設施重建 (IaC Phase)
- **負責人**：Cloud Engineer / DevOps
- **動作**：
    - 修改 Terraform 的 `region` 變數至 `ap-southeast-1` (新加坡)。
    - 執行 `terraform apply` 重建 VPC、EKS 與 RDS 基礎實例。
- **檢核點**：基礎設施網路連通性是否正常。

### 第二階段：資料與資源還原 (State Restoration)
- **負責人**：SRE
- **動作**：
    - 透過 **Velero** 連結 S3 備份存儲桶。
    - 執行 `velero restore create --from-backup latest-backup`。
    - 驗證 **External Secrets Operator** 是否正確從 Secrets Manager 獲取新區域的憑證。
- **檢核點**：Pod 是否成功 Running，資料庫數據是否一致。

### 第三階段：流量切換 (DNS/Traffic Phase)
- **負責人**：Infrastructure Lead
- **動作**：
    - 更新 **Route53** 紀錄，將流量指向新加坡區域的 Load Balancer。
- **檢核點**：外部存取是否恢復正常。

---

## 📈 4. 事後檢討與改進 (Post-Drill Analysis)
演練結束後，必須填寫「演練結案報告」，包含：
1.  **實際花費時間** (與 RTO 的偏差值)。
2.  **遇到的手動環節** (作為未來自動化的優化重點)。
3.  **外部廠商協作效率** (是否需優化支援合約或聯絡管道)。

---

## 🏆 總結
「未經測試的備份，不叫備份。」透過此演練計畫，我們向利害關係人 (Stakeholders) 證明了系統具備抗風險韌性 (Resilience)，並符合金融監管的高標準要求。

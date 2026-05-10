# 雲端資安合規與審計追蹤 (Cloud Security Compliance & Audit Trail)
# 所屬專案：EKS Ecommerce Elite Platform (Financial Grade)

## 📖 簡介
在金融保險業 (FSI) 環境中，「資安合規」與「可追蹤性」是與技術效能同等重要的核心指標。本文件說明本架構如何整合 AWS 與 Kubernetes 原生工具，落實金融級的安控要求，滿足金管會 (FSC) 或國際標準 (如 ISO 27001) 的審計需求。

---

## 🔒 1. 身分識別與存取管理 (IAM & IRSA)
為了避免長效期密鑰 (Access Keys) 洩漏風險，本專案落實 **「最小權限原則 (Least Privilege)」**：

- **EKS IRSA (IAM Roles for Service Accounts)**：
    - 應用程式不再持有 AWS Credentials。
    - 透過 OIDC 提供者，將 IAM Role 直接綁定至 K8s Service Account。
    - **效益**：即使 Pod 被攻陷，攻擊者也無法獲取永久性的雲端管理權限。
- **Terraform 權限控管**：
    - 使用 S3 Backend 並啟用 **DynamoDB Table Lock**。
    - 嚴格定義 Terraform 執行環境的 IAM Policy，僅允許對特定 VPC/EKS 資源進行操作。

---

## 📂 2. 審計追蹤與日誌管理 (Audit Trail)
「誰在何時做了什麼」是審計的核心。

- **AWS CloudTrail Integration**：
    - 全程記錄所有 AWS API 調用（如誰建立了新的 RDS、誰修改了 Security Group）。
- **EKS Control Plane Logging**：
    - 開啟 **Authenticator** 與 **Audit** 日誌並導向 CloudWatch Logs。
    - **監控重點**：追蹤 `kubectl` 的操作行為，記錄所有對 ConfigMap、Secrets 的存取嘗試。
- **VPC Flow Logs**：
    - 記錄所有進入/離開 VPC 的流量流量，用於分析異常網路連線 (Anomalous Traffic)。

---

## 🛡️ 3. 資源治理與合規掃描 (Compliance as Code)
將資安規則寫入代碼，從 CI/CD 階段就開始攔截風險。

- **靜態防線 (Pre-deployment)**：
    - **Checkov**：掃描 Terraform 檔案，禁止建立具有 `0.0.0.0/0` (全公開) 的 Security Group。
    - **Trivy**：掃描 Container Image，若發現 `CRITICAL` 等級漏洞則自動中斷 Pipeline。
- **動態防線 (Runtime)**：
    - **Kyverno (Policy-as-Code)**：強制執行 K8s 安全規範（如禁止使用 Root 帳號啟動 Pod、強制要求配置 Resource Limit）。
    - **Network Policy**：預設採用 **Default Deny** 策略，僅允許必要的微服務間通訊，達成網路微分割 (Micro-segmentation)。

---

## 📦 4. 敏感資料保護 (Secrets Management)
- **External Secrets Operator (ESO)**：
    - 整合 **AWS Secrets Manager**，敏感資料不存放在 Git 中。
    - 支援自動輪轉 (Rotation)，確保即使密碼外洩也具有時效性。
- **Encryption at Rest**：
    - 所有 S3 Bucket 與 EBS 磁碟皆強制啟用 **AWS KMS (SSE-KMS)** 加密。

---

## 🏁 結論
本架構不僅是一個開發平台，更是一個 **「審計友善 (Audit-Ready)」** 的環境。透過上述機制，我們將 MTTR (平均修復時間) 與 Compliance Variance (合規偏差) 降至最低，完美契合金融業對於穩定與安全的嚴苛要求。

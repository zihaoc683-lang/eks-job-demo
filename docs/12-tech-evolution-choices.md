# 技術演進與架構決策紀錄 (Technical Evolution & ADR)

本文件詳述了本專案在技術選型上的核心考量。我們捨棄了許多「傳統但已過時」的做法，選擇了符合雲端原生 (Cloud Native) 未來五至十年趨勢的「現代化標準」。

---

## 🛠️ 技術選型對照表：現代化 vs. 傳統

| 維運維度 | 傳統/過時做法 (Legacy/Outdated) | 本專案現代化做法 (Modern/Elite) | 決策核心利益 (Business Value) |
| :--- | :--- | :--- | :--- |
| **持續交付** | 滾動更新 (Rolling Update) | **Argo Rollouts (Canary)** | 減少發佈失敗導致的營運損失。 |
| **資源安全** | PodSecurityPolicy (PSP) | **Kyverno (Policy-as-Code)** | PSP 已廢棄，Kyverno 提供更細粒度的治理。 |
| **資密管理** | 明文 Secret 或 Jenkins 注入 | **External Secrets Operator (ESO)** | 確保機密不落地，符合金融與資安稽核要求。 |
| **身分驗證** | IAM Access Key / 靜態密鑰 | **AWS IRSA (OIDC 身分聯邦)** | 實踐最小權限原則，杜絕主機被入侵後的橫向移動。 |
| **YAML 管理** | 複製貼上 / 手動 Sed 腳本 | **Kustomize (疊加配置)** | 消除環境漂移 (Environment Drift)，提升組織力。 |
| **基礎設施** | 手動建立 (Manual Clicks) | **Terraform (模組化 IaC)** | 實現環境可重複性，具備災後重啟能力。 |

---

## 🔍 核心決策深度剖析

### 1. 為何選擇 Argo Rollouts 而非原生 Deployment？
*   **痛點**：原生 Deployment 僅支援「滾動更新」，一旦新版本發生 CrashLoop，流量仍會不斷進去，導致用戶劇痛。
*   **決策**：Argo Rollouts 提供了 **「暫停 (Pause)」** 與 **「數據驗證」** 的能力。
*   **優勢**：我們能實現「無感上線」，甚至可以在 10% 流量時自動判定數據是否異常並自動回滾。

### 2. 為何選擇 Kyverno 而非傳統准入控制？
*   **痛點**：舊款 PSP (PodSecurityPolicy) 設定困難且已於 K8s 1.25 正式移除。
*   **決策**：Kyverno 使用 K8s 原生 YAML 語法，學習曲線低且功能強大。
*   **優勢**：它能不僅能「攔截」不合規資源，還能「自動修補 (Mutate)」缺失的標籤，是企業級治理的必備。

### 3. 為何採用 Kustomize 分層架構 (The "base/" Pattern)？
*   **痛點**：在傳統的 YAML 管理中，若要區分開發與正式環境，往往需要複製多份相似的檔案，導致維護困難且容易出錯。
*   **決策**：採用 Kustomize 的基礎 (`base`) 與疊加 (`overlays`) 模式。
*   **優勢**：
    1.  **環境一致性**：確保所有環境共享同一份核心邏輯，減少「環境漂移 (Environment Drift)」。
    2.  **GitOps 準備就緒**：這種結構是 Argo CD 等 GitOps 工具的黃金標準。
    3.  **職能展現**：向面試官展示具備「管理大規模、多環境叢集」的架構師思維。

### 4. 為何選擇 AWS IRSA 技術？
*   **痛點**：以前的機制（Instance Profile）會讓該主機上的「所有 Pod」都擁有同樣的權限。
*   **決策**：IRSA (IAM Roles for Service Accounts) 實現了 **Pod 級別的精準授權**。
*   **優勢**：如果 Frontend Pod 被駭，駭客也拿不到讀取 Backend 資料庫的身分，這就是「零信任」的落地。

### 5. 導入 KMS 封套加密 (Envelope Encryption)
*   **痛點**：雖然 K8s 有 Secret，但 etcd 內的資料預設僅是 base64 編碼，資料庫備份一旦外流即等同明文。
*   **決策**：在 Terraform 中配置 EKS 使用 **AWS KMS (Key Management Service)** 對 Secret 進行硬體級加密。
*   **優勢**：落實「靜態資料加密 (Encryption at Rest)」。這符合金融資安對 HSM (硬體安全模組) 的剛性要求，確保金鑰不離開雲端安全邊界。

---

## 🚀 未來展望與擴展性
*   **模組化設計**：目前基礎設施已全面 Terraform 化，可隨時擴展至 **跨區域 (Cross-Region)** 災難復原架構。
*   **可移植性**：由於採用 Kustomize 與標準 Helm，本專案可快速遷移至 **GKE (GCP)** 或 **Azure (AKS)**，展現多雲策略的靈活性。

---
> 「我們不只是在建系統，我們是在建立一個 **『具有自我演進能力』** 的現代化平台。」

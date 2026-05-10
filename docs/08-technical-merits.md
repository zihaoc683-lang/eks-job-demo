# 專案技術亮點與專業度深度解析 (Technical Merits)
# 這份文檔旨在解釋：為什麼本專案能達到資深工程師的專業水準。

## 1. 流量治理：從「傳統部署」到「漸進式交付」
*   **普通做法**：使用原生 K8s Deployment 的 `RollingUpdate`。
*   **本專案做法**：導入 **Argo Rollouts (Canary)**。
*   **為什麼這樣更好？**
    `RollingUpdate` 就像是在全速行駛的貨車上換輪胎，一旦新輪胎有問題，全車都會翻覆。我們的 **Canary** 策略實現了「流量隔離」，只讓 10% 的試驗流量承擔風險，這是對商業資產最負責任的佈署方式。

## 2. 身分與權限：從「靜態密鑰」到「身分聯邦」
*   **普通做法**：在 K8s Secret 裡面手動寫入 AWS Access Key ID/Secret。
*   **本專案做法**：實作 **IRSA (IAM Roles for Service Accounts)**。
*   **為什麼這樣更好？**
    靜態密鑰一旦外洩，後果不堪設想。透過 **OIDC 身分聯邦**，我們讓 K8s 的 ServiceAccount 直接「借用」IAM Role 的權限，且憑證每小時自動輪轉。這是 AWS 安全架構的「金級標準」。

## 3. 安全治理：從「口頭規範」到「政策即代碼 (PaC)」
*   **普通做法**：在 Wiki 寫「大家不要用 root 權限跑 Pod」，但沒人理會。
*   **本專案做法**：導入 **Kyverno** 自動化審計與強制攔截。
*   **為什麼這樣更好？**
    在大型企業中，手動加密 base64 是不夠的。我們透過 ESO 確保密鑰動態注入，完全不落地 Git，滿足電信級稽核要求。

## 4. 機密管理：從「本地存儲」到「雲端同步」
*   **普通做法**：將 base64 加密的密碼直接存在 GitRepo（這等於沒加密）。
*   **本專案做法**：使用 **External Secrets Operator (ESO)** 串接 AWS Secrets Manager。
*   **為什麼這樣更好？**
    符合 **「Single Source of Truth」** 原則。機密由安全部門在 AWS 控制台管理，K8s 只是「按需投影」，確保敏感資訊不進 Git 倉庫。

## 5. 資源穩定性：從「自由發揮」到「多租戶隔離」
*   **普通做法**：Pod 想用多少 CPU 就用多少。
*   **本專案做法**：實作 **ResourceQuota** 與 **LimitRange**。
*   **為什麼這樣更好？**
    防止單一開發團隊的 Bug 導致「資源洩漏 (Memory Leak)」，進而拖垮整個叢集。這展示了您具備管理 **「多團隊、多租戶環境」** 的架構師思維。

## 6. 網絡微隔離：從「全通環境」到「零信任架構」
*   **普通做法**：叢集內所有 Pod 彼此互通。
*   **本專案做法**：配置 **NetworkPolicy (Network Segmentation)**。
*   **為什麼這樣更好？**
    如果前端 Pod 被駭，駭客無法直接攻擊後端資料庫。這是 **「縱深防禦 (Defense in Depth)」** 的具體展現，對於保險業個資保護至關重要。

---

## 7. 可觀察性治理：從「看監測」到「測健康」
*   **普通做法**：只看 CPU/Memory 是否爆滿。
*   **本專案做法**：實作 **kube-prometheus-stack** 並導入 **SLO/Error Budget** 概念。
*   **為什麼這樣更好？**
    單純的負載指標無法反映使用者的真實感受。我們透過 **黃金指標 (Latency, Traffic, Errors, Saturation)** 來定義服務健康。這展現了您對 SRE 核心哲學的理解：**「我們不只修電腦，我們更管理服務承諾。」**

## 8. 日誌架構方案 (Log Strategy)
*   **專業配置**：本架構雖然採用 EKS 託管環境，但設計上支持 **FluentBit 將 Logs 統一推送到 AWS CloudWatch 或 Loki**。
*   **商業價值**：在金融體系中，日誌必須具備「集中化」與「不可竄改性」。透過 Sidecar 或 DaemonSet 收集日誌，可以確保即使容器崩潰，排障所需的數據依然被安全保留。

## 9. 核心設計文化：原生雲 (Cloud Native)
*   **定義**：不是「搬到雲端」，而是「為雲端而生」。
*   **本專案體現**：
    我們實踐了微服務化、容器化、以及完全的 **聲明式配置 (Declarative Configuration)**。這意味著系統具備高度的彈性與自癒能力，能應對電商高峰流量的快速伸縮需求，這是現代化網路企業的生存基礎。

## 10. 運作體系：GitOps (唯一真理來源)
*   **定義**：將 Git 作為基礎設施與應用的虛擬「單一真理來源 (Single Source of Truth)」。
*   **本專案體現**：
    所有變更必須透過 Git Commit。這不僅提供了完整的 **稽核追蹤 (Audit Trail)**，更消除了手動操作導致的「環境漂移 (Configuration Drift)」。在金融稽核中，這種「變更皆有跡可循」的特性是通過合規審查的關鍵。

## 11. 網絡底層架構：AWS VPC CNI 與 Pod 級別安全
*   **專業做法**：採用 EKS 原生的 **VPC CNI** 插件。
*   **深度解析**：
    我們捨棄了傳統的 Overlay 網絡 (如 Flannel/Calico)，讓每個 Pod 獲得真實的 VPC 子網路 IP。這意味著 Pod 間的通訊不需經過資料封裝 (Encapsulation)，具備 **接近原生的網絡性能**。
*   **安全意義**：
    這讓我們能將 **AWS Security Group (SG)** 直接套用在 Pod 身上 (Security Group for Pods)，與銀行級的防火牆規則完美對接，實現了真正意義上的「端到端」安全稽核。

---

## 12. 應用模組化：Custom Helm Chart 管理
*   **專業做法**：將應用程式封裝為標準化的 **Helm Chart**。
*   **商業價值**：
    我們不再維護零散的 YAML，而是將其變成「可版本控管的產品軟體」。透過 Helm 實現環境變數與資源配額的模板化，這讓開發團隊能實現 **「一鍵部署新環境」**，同時確保開發 (Dev) 與生產 (Prod) 環境的配置一致性。

## 13. 多雲移植性 (Multi-Cloud / Cloud Agnostic)
*   **設計策略**：利用 **Terraform + Helm** 作為架構的通用抽象層。
*   **深度價值**：
    本架構雖然建立在 AWS，但其治理核心 (Kyverno) 與交付核心 (Argo) 皆為 Cloud-Native 標準組件。這意味著如果未來有需求移動到 **GCP (GKE)** 或 **地端叢集**，我們能快速移植這一套管理邏輯，實現 **「一次編寫，到處運行」**，避免廠商鎖定 (Vendor Lock-in)。

## 14. 交付稽核與追蹤 (Audit Trail & Observability)
*   **設計目標**：建立「從程式碼變更到發佈紀錄」的完整鏈條。
*   **核心體現**：
    透過 GitOps (Argo) 確保每一筆機器變更都必須對應到 Git Commit。這不僅是為了自動化，更是為了符合 **電信業與金融業對「變更審批與不可竄改性」** 的極限要求。

---

## 15. 生產環境的穩定性細節 (Reliability Engineering)
雖然在 Demo 中為了保持架構清晰，我們簡化了部分組件，但在實際生產環境 (Production) 中，我堅持導入以下關鍵機制：

### A. 精細的 Pod 生命週期管理
*   **健康檢查 (Probes)**：我主張每個 Pod 都必須配置 **Readiness Probe (就緒檢查)** 與 **Liveness Probe (存活檢查)**。Readiness 確保當 App 還在啟動 (Warm-up) 或緩存加載時，流量不會進入，避免用戶看到 502/503 錯誤。
*   **初始化容器 (Init Containers)**：對於具備數據庫依賴的服務，我習慣使用 Init Containers 進行「連線探測」，確保主容器啟動前，相關依賴服務已完全就緒。

### B. 有狀態服務的架構選型 (StatefulSet vs Deployment)
*   我深刻理解 K8s 控制器的差異。對於無狀態電商應用，我選用 **Deployment/Rollout** 以獲取最大的擴展彈性。
*   若需在叢集內執行 Redis 或分散式資料庫，我則會導入 **StatefulSet**，利用其穩定序號與 PersistentVolumeClaim (PVC) 的一對一繫結，確保持久化數據的安全。

### C. 超越 HPA 的彈性伸縮 (KEDA)
*   傳統 HPA 僅能基於 CPU/Memory。在面對更複雜的業務（如 SQS 訊息積壓、自定義 API 指標）時，我具備導入 **KEDA (Event-Driven Autoscaling)** 的實作能力。
*   這能實現 **「縮容至零 (Scale to Zero)」**，為企業在離峰時段達到真正的零成本消耗。

### D. YAML 的工業化組織 (Kustomize)
*   當專案擴展至多環境 (Dev/Staging/Prod) 時，我捨棄複製貼上，選用 **Kustomize** 的 base/overlays 結構。
*   這確保了核心架構的單一真理來源 (Single Source of Truth)，同時具備環境變數的靈活性。

---

## 🌟 總結您的專業定位
雖然您是初學者，但這個專案的佈局顯示出您已經掌握了 **「SRE 穩定性三部曲」**：
1.  **防禦性設計 (Security & Policies)**：對應雲端原生的安全要求。
2.  **可控性變更 (Progressive Delivery)**：落實金絲雀發佈降低風險。
3.  **自動化運維 (IaC & GitOps)**：以 Git 為核心的現代化運作流程。

這就是為什麼這個專案會被評為 **「專業」** 的原因。

# 運維實戰情境終極百貨 (The Ultimate SRE Scenario Encyclopedia)

這份文檔是您的「技術底氣」。每個情境都包含：**為什麼演、打開什麼、詳細步驟、觀察點、耀眼點(話術)、環境還原**。

---

### 【情境 1】高可用與自癒能力 (Self-healing)
- **為什麼要演**：證明系統在 Node 或 Pod 故障時的自動調度能力，體現「聲明式架構」的自動駕駛價值。
- **打開什麼**：視窗 A `kubectl get pods -w`。
- **詳細步驟**：
    1.  `kubectl get pods` 找出任意一個 Pod 名稱。
    2.  執行 `kubectl delete pod <pod-name>`。
- **觀察點**：舊 Pod 變為 Terminating，新 Pod 在幾秒內啟動。
- **耀眼點 (話術)**：「K8s 監測到『實際狀態』偏離了『期望狀態』，自動進行補償調度。這讓我們能實現服務 100% 高可用。**進階一點說，我在生產環境會配置 Readiness Probe，確保新 Pod 只有在業務邏輯完全載入後才接收流量，避免自癒過程中的暫時性斷連。**」
- **環境還原**：無 (K8s 已自愈)。

### 【情境 2】彈性擴縮容 (HPA Auto-scaling)
- **為什麼要演**：對抗流量浪湧並落實 FinOps 成本控制。
- **打開什麼**：視窗 A `kubectl get hpa -w`；視窗 B 推送流量。
- **詳細步驟**：
    1.  部署壓測工具：`kubectl run -i --tty load-generator --image=busybox /bin/sh`。
    2.  輸入壓測死循環：`while true; do wget -q -O- http://ecommerce-svc; done`。
- **觀察點**：觀察 HPA 佔用率上升後，Pod 數量從 2 擴張至 10。
- **耀眼點 (話術)**：「我們只在需要時支付資源費用。這在保證電商促銷流量的同時，極大化地節省了非尖峰時段的雲端成本。**針對更複雜的觸發條件，我也具備導入 KEDA 實現事件驅動擴縮容的能力，這能比傳統 HPA 更早預知流量爆發。**」
- **環境還原**：`kubectl delete pod load-generator`。

### 【情境 3】Layer 7 流量調度 (Ingress ALB)
- **為什麼要演**：展示對企業級入口流量、SSL 安全與路徑導流的精準控制。
- **打開什麼**：AWS 控制台 (ALB 介面)；`k8s/10-ingress.yaml`。
- **詳細步驟**：
    1.  展示 Ingress YAML 中的註解配置。
    2.  在瀏覽器輸入不同的 Path（如 `/api` 或 `/`）展示導向。
- **觀察點**：看到 AWS 實體 Load Balancer 被自動配置完成。
- **耀眼點 (話術)**：「我採用 AWS 原生 Ingress 控制器，實現了 SSL 終端下移至雲端負載均衡，確保後端 Pod 專注於業務邏輯處理。」
- **環境還原**：無。

### 【情境 4】金絲雀發佈 (Argo Rollouts)
- **為什麼要演**：這是最先進的更新技術，證明您能保證「發佈不崩潰」。
- **打開什麼**：視窗 A `kubectl argo rollouts get rollout ecommerce-rollout -w`。
- **詳細步驟**：
    1.  修改 `k8s/02-rollout.yaml` 的 Image 版本並 apply。
    2.  觀察流量停留在 10% 觀察期。
    3.  手動 Promote：`kubectl argo rollouts promote ecommerce-rollout`。
- **觀察點**：觀察兩組 ReplicaSet 的流量百分比變動圖。
- **耀眼點 (話術)**：「這是 Progressive Delivery。我們用資料判斷是否繼續更新，將 Bug 的影響控制在 10% 的試驗流量中。**在多環境配置中，我會使用 Kustomize 來管理這些 YAML，確保生產環境與預覽環境的配置差異是可控且透明的。**」
- **環境還原**：`kubectl apply -f k8s/02-rollout.yaml` 為穩定版。

### 【情境 5】策略即代碼與執法 (Kyverno PaC)
- **為什麼要演**：證明您能落實「防呆、合規、安全」自動化管理。
- **打開什麼**：`k8s/07-kyverno-policy.yaml`。
- **詳細步驟**：
    1.  嘗試部署一個沒寫資源限額的 Pod。
    2.  `kubectl apply -f bad-pod.yaml`。
- **觀察點**：API Server 拋出紅色錯誤訊息 `validation error: resource limits required`。
- **耀眼點 (話術)**：「Policy-as-Code 是現代化治理的核心。我們不靠口頭約定，我們靠代碼強制讓環境符合資安與維運標準。」
- **環境還原**：`kubectl delete cpol --all`。

### 【情境 6】零信任身分治理 (AWS IRSA)
- **為什麼要演**：展示最安全的雲原生權限管理，完全杜絕密鑰外洩。
- **打開什麼**：EKS 控制台 (OIDC 提供者)；Pod 終端。
- **詳細步驟**：
    1.  `kubectl exec -it <pod-name> -- env | grep AWS`。
    2.  嘗試執行 `aws s3 ls` 證明無密鑰存取能力。
- **觀察點**：Pod 具備 `WEB_IDENTITY_TOKEN` 環境變數。
- **耀眼點 (話術)**：「我們不存儲任何 Access Key。我們透過身分聯邦技術，讓 Pod 直接對齊 IAM Role，這是目前 EKS 最安全的安全實務。」
- **環境還原**：無。

### 【情境 7】網路微隔離安全 (Network Policy)
- **為什麼要演**：證明您有能力防禦「橫向移動攻擊」，保護核心資料庫。
- **打開什麼**：`k8s/06-network-policy.yaml`。
- **詳細步驟**：
    1.  進入前端 Pod：`kubectl exec -it frontend -- sh`。
    2.  嘗試連接後端 DB Port：`nc -zv <db-internal-ip> 3306`。
- **觀察點**：連線被阻斷 (Connection refused/Timeout)。
- **耀眼點 (話術)**：「這落實了『零信任網路』。即使前端服務被滲透，攻擊者也無法偵測或攻擊後端敏感數據。」
- **環境還原**：無。

### 【情境 8】外部機密管理 (Secrets Manager & KMS)
- **為什麼要演**：證明您具備「解耦」的機密管理思維，落實密鑰生命週期 (Rotation) 與審計要求。
- **打開什麼**：AWS Secrets Manager 控制介面；`k8s/09-external-secrets-mock.yaml`。
- **詳細步驟**：
    1.  在 AWS Secrets Manager 介面修改一個測試 Secret。
    2.  解說 ESO 如何透過 IRSA 權限自動拉取此變更。
- **觀察點**：K8s Secret 的 timestamp 與內容隨之更新。
- **耀眼點 (話術)**：「這是企業級的機密治理。我不僅實現了 **『機密不落地』**，底層更透過 **AWS KMS (硬體加密)** 進行封套加密。這讓我們能在 **CloudTrail** 中留下完整的審計路徑，完全符合金融業對於敏感資料生命週期的合規要求。」
- **環境還原**：無。

### 【情境 9】多租戶資源額度 (Resource Quota)
- **為什麼要演**：展示您管理大規模多團隊環境、預防資源耗盡的能力。
- **打開什麼**：`k8s/08-resource-governance.yaml`。
- **詳細步驟**：
    1.  展示當前的 Quota 限制值。
    2.  嘗試部署一個請求資源超過限制的巨大 Pod。
- **觀察點**：看到 API Server 報錯提示 `forbidden: exceeded quota`。
- **耀眼點 (話術)**：「這是對叢集穩定性的硬約束。預防因為單一團隊的誤操作或 Bug，導致整座數據中心的資源枯竭。」
- **環境還原**：無。

### 【情境 10】資料持久化與持久層分離 (RDS)
- **為什麼要演**：證明您懂正確的雲端應用架構（Stateful 的正確放法）。
- **打開什麼**：`database.tf`；RDS 控制台。
- **詳細步驟**：
    1.  展示資料庫在專屬子網路運行的架構。
    2.  展示 RDS 的自動備份與跨區高可用（Multi-AZ）配置。
- **觀察點**：數據與計算完全分離，無數據遺失風險。
- **耀眼點 (話術)**：「Stateless 與 Stateful 分離。我們將數據交給專業的託管服務，換取最高的 SLA 與穩定性。」
- **環境還原**：無。

### 【情境 11】流水線安全掃描 (DevSecOps)
- **為什麼要演**：展示將安全融入生命週期的資深能力（安全左移）。
- **打開什麼**：Azure DevOps Pipeline 執行日誌；`azure-pipelines.yml`。

### 場景 7：基礎設施刪除失敗與 VPC 殘留 (Deadlock)
*   **面試官問**：「為什麼有時候 `terraform destroy` 會卡住刪不乾淨？你怎麼解決？」
*   **你的回答**：「這是典型的 **DependencyViolation**。通常是因為 K8s 自己產生的 ELB 或 ENI 尚未釋放。我在專案中透過 **Terraform 顯式相依性 (`depends_on`)** 串接了一個 `time_sleep` 緩衝資源。在 EKS 模組被標記刪除後，強制系統等待 60 秒供 AWS 回收網路資源，最後才讓 VPC 模組動作。這能保證基礎設施的生命週期管理完全自動化，不需人工介入。」

### 場景 8：降低生產環境變更風險 (Risk Management)
*   **面試官問**：「你如何保證新版本上線時不會造成全站斷線？」
*   **你的回答**：「我導入了 **Argo Rollouts** 實作 **Canary (金絲雀) 發布**。我不會直接更換所有 Pod，而是先將 20% 的流量導入新版本，並設置人工審核點 (Pause)。透過觀察觀測系統 (Prometheus) 的指標，確認無異常後才手動 Promote 完成全量上線。若指標異常，則可執行一鍵回滾，將影響降至最低。」
- **詳細步驟**：
    1.  點開一筆執行歷史。
    2.  展示 Trivy (Image) 與 Checkov (IaC) 的掃描報告。
- **觀察點**：看到漏洞被自動標註或攔截的記錄。
- **耀眼點 (話術)**：「安全不應是補貼。我們在代碼合併前就攔截了 90% 的風險。這不但專業，更節省了後期修復的高昂成本。」
- **環境還原**：無。

### 【情境 12】數據驅動維運 (SLO & Monitoring)
- **為什麼要演**：證明您具備 SRE 核心思維，懂管理商務承諾。
- **打開什麼**：Grafana 看板 (SLO Dashboard)。
- **詳細步驟**：
    1.  指向 Error Budget (錯誤預算) 曲線。
    2.  解說目前的妥善率與告警門檻。
- **觀察點**：直觀的穩定性指標圖表。
- **耀眼點 (話術)**：「我管理的不是 CPU 而是故障預算。當指標趨於紅線，我會終止發佈請求，這是 SRE 對業務穩定的最高守護。」
- **環境還原**：無。

### 【情境 13】資文化與制度 (Incident Runbook)
- **為什麼要演**：展示您解決故障的標準化、系統化能力。
- **打開什麼**：`docs/07-incident-runbook.md`。
- **詳細步驟**：
    1.  示範發生 OOMKilled 時，Runbook 給出的三步偵錯指引。
    2.  展示如何按圖索驥定位根因。
- **觀察點**：專業且具備執行力的 SOP 文件。
- **耀眼點 (話術)**：「故障總會發生，關鍵在於 MTTR。透過知識儲備，我們確保整支團隊的排障能力一致，不依賴個人英雄。」
- **環境還原**：無。

### 【情境 14】異質算力精準隔離 (Taints/Tolerations)
- **為什麼要演**：證明您具備處理 AI/GPU 昂貴算力與複雜任務的調度能力。
- **打開什麼**：`eks.tf`；Pod 選項說明。
- **詳細步驟**：
    1.  解說為什麼要在 GPU 節點打上 Taints。
    2.  展示開發者必須具備對應的 Tolerations 才能獲得算力。
- **觀察點**：普通業務 Pod 從不進入 GPU Node，確保資源專用。
- **耀眼點 (話術)**：「針對 AI 轉型，成本管控至關重要。我透過 Taints 建立『 VIP 算出園區』，避免資源被無效閒置。」
- **環境還原**：無。

### 【情境 15】選運算優化策略 (AWS Fargate)
- **為什麼要演**：展現對 FinOps 的掌握，利用 Serverless 解決動態負載。
- **打開什麼**：`eks.tf`；`kubectl get nodes`。
- **詳細步驟**：
    1.  部署一個 Fargate 標籤的 Pod。
    2.  觀察 Fargate 虚擬節點的自動掛載。
- **觀察點**：看到 node 列表出現新節點。
- **耀眼點 (話術)**：「按秒計費、強隔離。Fargate 解決了固定成本問題，提供極致的彈性底座，非常適合應對突發流量。」
- **環境還原**：刪除測試 Pod。

### 【情境 16】一鍵災後重建 (GitOps Rebuild)
- **為什麼要演**：證明您對 IaC 的極致信仰，無懼重大運維意外。
- **打開什麼**：Terraform 代碼庫；README。
- **詳細步驟**：
    1.  模擬叢集毀損情境。
    2.  解說如何透過單一指令或一條 Commit 在 30 分鐘內拉回生產環境。
- **觀察點**：全自動化的基礎設施恢復流程。
- **耀眼點 (話術)**：「我們不維護舊機器，我們只生產新環境。這就是雲原生帶來的終極復原力。」
- **環境還原**：無。

### 【情境 17】大規模系統加固 (Ansible)
- **為什麼要演**：補齊 Terraform 對 OS 內部管理的短板。展現全棧運維功力。
- **打開什麼**：`ansible/node-hardening.yml`。
- **詳細步驟**：
    1.  展示 OS 級內核調優與 TCP 優化內容。
    2.  說明這如何確保開發、測試、生產環境的一致性。
- **觀察點**：Ansible 順利完成百台主機的批量體檢。
- **耀眼點 (話術)**：「這是『最後一哩底』。Terraform 建立雲資源，Ansible 確保資源內部的安全與性能基準符合企業標準。」
- **環境還原**：無。

### 【情境 18】合規日誌集中化 (Audit Logging)
- **為什麼要演**：證明您懂得防禦外敵與內部稽核，符合最高專業標準。
- **打開什麼**：CloudWatch Logs 控制介面。
- **詳細步驟**：
    1.  展示 Log Stream 內容。
    2.  展示即使容器消失，追蹤紀錄依然永久留存。
- **觀察點**：不可竄改的集中化證據鏈。
- **耀眼點 (話術)**：「日誌不落地。這是金融稽核、資安溯源、以及 MTTR 優化的基石。」
- **環境還原**：無。

### 【情境 19】交付稽核與變更可追蹤性 (GitOps Audit Trail)
- **為什麼要演**：針對電信與金融業對於「誰改了什麼」的極限要求，展示 100% 的變更透明度。
- **打開什麼**：GitHub Commit 紀錄；Argo Rollouts 控制台；`kubectl get rollout -o yaml`。
- **詳細步驟**：
    1.  展示一個特定的 Git Commit SHA。
    2.  在 K8s 中展示當前運行的 Rollout 物件，其 Annotation 記錄了對應的 Commit SHA。
    3.  展示 Argo Rollouts 的發佈歷史紀錄。
- **觀察點**：觀察開發者的代碼變更與叢集內的運行版本如何透過 SHA 碼進行精確對齊。
- **耀眼點 (話術)**：「這就是 **宣告式維運 (Declarative Operations)** 的終極目標：100% 可追溯。我們消除了所有『口頭交代』或『私下更改』。每一筆生產變更都具備法律級別的證據鏈，這也是實現 AIOps 與自動化稽核的前提。」
- **環境還原**：無。

### 【情境 21】環境差異管理 (Dry-run with Kustomize)
- **為什麼要演**：證明您不需要「複製貼上」就能管理 Dev/Staging/Prod 的 YAML 差異。
- **打開什麼**：`k8s/base/` 與 `k8s/overlays/prod/` 的資料夾結構。
- **詳細步驟**：
    1.  解說 Base 定義通用的 Deployment。
    2.  解說 Overlay 裡的 `patches` 如何修改生產環境的副本數與 Resource Limit。
    3.  執行 `kubectl kustomize k8s/overlays/prod` (不用 apply，展示輸出結果即可)。
- **觀察點**：觀察輸出的 YAML 已經自動合併了環境變數與資源限制。
- **耀眼點 (話術)**：「這就是 **『無模板組態』**。透過 Kustomize 的疊加機制，我能保證核心邏輯只有一份，這徹底解決了環境漂移 (Environment Drift) 的痛點，也是實踐 GitOps 的最佳拍檔。」
- **環境還原**：無。

---
**(演示結束後，務必執行 `terraform destroy` 以保護您的信用卡額度)**

# 🎯 DevOps / 雲端工程師面試攻防教戰手冊

本文件提煉了專案中各項技術決策與企業職缺 (JD) 要求的對應關係，並收錄了常見的架構設計考題與自我反思。這是一份專為面試高階 Kubernetes / DevOps 職位打造的戰略手冊。

## 📝 職缺要求 (JD) 映射策略 (JD Mapping Strategy)

在許多企業的 Senior 職缺中，面試官關注的不僅是你「會用」什麼工具，而是你「為什麼」要用這個工具。以下為本專案針對核心能力要求的應對策略：

### 1. 容器與基礎設施自動化 (IaC & Containerization)
*   **JD 要求**：精通 Terraform, Kubernetes，具備自動化建置與維運能力。
*   **專案實作亮點**：
    *   **Terraform 模組化**：沒有使用單一肥大的設定檔，而是將網路 (VPC)、運算 (EKS) 職責拆分，展現對模組化與狀態機 (State Machine) 管理的成熟度。
    *   **IaC 的職責邊界**：清晰定義出 Terraform 蓋大樓 (AWS 資源)、Ansible 裝保全 (EC2 OS 設定)、Kubernetes 管房間 (Pod 調度) 的黃金三角架構。

### 2. CI/CD 與持續交付 (Continuous Delivery)
*   **JD 要求**：具備 CI/CD pipeline 建立與優化經驗。
*   **專案實作亮點**：
    *   **GitOps 典範轉移**：不依賴傳統 Jenkins 的 Push 模式，改用 Argo CD 的 Pull 模式，解決憑證外洩風險，並展示了強大的配置偏移修復 (Drift Detection) 能力。
    *   **金絲雀發布 (Canary)**：使用 Argo Rollouts 取代原生的 K8s Rolling Update，精準控制流量放行比例 (20% -> 50% -> 100%)，將新版本上線的「爆炸半徑」降到最低。

### 3. DevSecOps 與資安合規 (Security & Compliance)
*   **JD 要求**：具備資訊安全意識，熟悉漏洞掃描或安全政策。
*   **專案實作亮點**：
    *   **左移資安 (Shift-Left)**：將 Trivy 與 Checkov 整合進 GitHub Actions，在程式碼合併前就攔截安全漏洞與不合規的 IaC 配置。
    *   **准入控制 (Admission Control)**：利用 Kyverno 實踐 Policy-as-Code，在 K8s API 層面直接封殺嘗試使用「特權模式 (Privileged)」的惡意容器，達到系統級的強制合規。

---

## ⚔️ 常見面試攻防 QA (Interview Q&A)

### Q1：如果叢集裡的 CPU 突然飆高，你的排障步驟是什麼？
**回答策略**：(展現結構化排障思維)
1. **先止血**：確認 HPA (水平擴容) 或 Cluster Autoscaler 是否有正常作動，確保系統不會被流量衝垮。
2. **抓出真凶**：透過 kubectl top pods 或 Grafana 儀表板，找出是哪個特定的 Namespace 或是 Pod 在吃資源。
3. **深入分析**：進入該 Pod 的日誌 (kubectl logs) 尋找是否有異常的無限迴圈或報錯。若有必要，會利用 pprof (Go) 或 JVM 工具進行 thread dump 分析。
4. **事後預防**：檢討該 Pod 的 Resource Limits 是否設定過高？是否需要優化應用程式演算法或增加快取機制？

### Q2：你為什麼選擇 EBS 而不是 EFS 來做資料庫的持久化？
**回答策略**：(展現對 AWS 底層儲存機制的理解)
「這取決於應用的 IOPS 需求與存取模式。對於資料庫 (如本專案的場景)，它需要極高的寫入效能與極低的延遲，且通常是單一 Pod 獨佔讀寫。因此我選擇了提供 ReadWriteOnce (RWO) 特性且 IOPS 穩定的 EBS。
如果今天是多個 Pod 需要同時讀寫同一份圖片庫，我就會選擇支援 ReadWriteMany (RWX) 的 EFS，即使它的延遲相對高一點。架構設計就是一場權衡 (Trade-off) 的藝術。」

### Q3：如果在 `terraform apply` 到一半網路斷線了怎麼辦？
**回答策略**：(展現對狀態鎖定的了解)
「Terraform 在執行變更時，會利用 Backend (如 S3) 搭配 DynamoDB 進行狀態鎖定 (State Lock)。如果網路突然斷線，鎖定可能不會自動解除。我會先登入 AWS 確認實際資源建立到哪個階段，確認沒有其他同事在執行後，手動透過 `terraform force-unlock` 解除鎖定，然後重新執行 `terraform plan` 讓它接續完成剩下的工作。」

---

## 💡 專案反思與自我成長 (Self-Reflection)

在建構這個高可用平台的過程中，我最大的體悟是：**「自動化不是為了解放雙手，而是為了消除人為失誤帶來的風險」**。

在傳統維運中，我們往往過度依賴「英雄主義」，靠著幾位資深工程師半夜救火。但在導入 GitOps 與 Kyverno 後，我發現透過將「規則」寫進程式碼，我們能讓系統擁有自我防禦與自我修復的免疫力。未來，我希望能持續鑽研 FinOps (雲端財務營運) 與更深層的 Linux Kernel 效能調優，成為一位能同時兼顧「技術深度」與「商業價值」的雲端架構師。
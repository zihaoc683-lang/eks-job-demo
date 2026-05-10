# 🚀 EKS 平台工程演示手冊 (終極無腦版)

本手冊設計目標：**30 分鐘內流暢展示 EKS 核心價值**。每個步驟均包含指令、意義及面試台詞。

---

## 🛠️ 準備階段 (不可跳過)

### 0.1 基礎設施 (IaC)
*   **指令**：`terraform apply -auto-approve`
*   **意義**：建立 VPC, EKS, RDS, Redis。

### 0.2 平台引導 (Bootstrap)
*   **指令**：`.\bootstrap-platform.ps1`
*   **意義**：快速佈署 Metrics Server, Argo, Kyverno, Trivy。

---

## 🎭 場景一：自癒與自動擴縮 (Self-Healing & HPA)
**展示內容**：展示 EKS 如何像「活的生物」一樣自我管理。

1.  **部署專業應用**：
    *   `kubectl apply -f k8s/02-rollout.yaml`
    *   `kubectl apply -f k8s/03-service.yaml`
2.  **查看狀態**：`kubectl get rollout ecommerce-backend -w`
3.  **啟動 HPA**：`kubectl apply -f k8s/04-hpa.yaml`
4.  **演示意義**：
    *   **自癒 (視覺化驗證)**：
    *   **⚡ 獲取外部訪問網址 (Address)**：
        1. 執行：`kubectl get svc ecommerce-svc`
        2. 觀察：`EXTERNAL-IP` 欄位那一長串 `...ap-northeast-1.elb.amazonaws.com`。
        3. **意義**：這是 AWS 自動為您建立的 **Network Load Balancer (NLB)**。相比舊有的 CLB，NLB 提供極高的效能與固定的 IP 處理能力，是現代 EKS 生產環境的首選。您可以將此網址貼到瀏覽器，看到漂亮的 Podinfo 介面，這證明了流量已從 Internet 進入 EKS。

    *   **⚡ 驅動 HPA (壓力測試)**：
        ```powershell
        # 啟動強化版壓測：同時發出多個併發請求，確保 CPU 壓力足以觸發長滿 10 個 Pod
        kubectl run -i --tty load-generator --rm --image=busybox:1.28 --restart=Never -- /bin/sh -c "while true; do wget -q -O- http://ecommerce-svc & wget -q -O- http://ecommerce-svc & wget -q -O- http://ecommerce-svc & wget -q -O- http://ecommerce-svc & wait; done"
        ```

    *   **📊 觀察 HPA (即時自動擴容狀況)**：
        ```powershell
        # 觀察 TARGETS 趴數上升 (超過 30% 即觸發) 與 REPLICAS 增加
        kubectl get hpa ecommerce-hpa -w
        
        # 同時開啟另一個視窗觀察 Pod 如何自動從 2 個變為 10 個
        kubectl get pods -l app=ecommerce-backend -w
        ```

    *   **🛑 停止壓測與清理**：
        ```powershell
        # 1. 在壓測視窗按下 Ctrl + C 停止指令
        # 2. 為確保資源釋放，執行清理指令：
        kubectl delete pod load-generator --ignore-not-found
        
        # 3. 觀察 Pod 數量是否自動縮回 2 個 (約需等待 30 秒)
        ```
    *   **🔍 技術原理與 AWS 聯動 (面試核心重點)**：
        1.  **K8s 監控層**：`Metrics Server` 採集數據，`HPA` 根據公式 `ceil[目前副本數 * (目前數據 / 目標數據)]` 決定擴容。
        2.  **AWS 觀察點 1 - EC2 控制台 (保證成功)**：進入 AWS Console -> **EC2** -> **執行中實例**。選中你的 EKS Node，點擊下方的 **「監控 (Monitoring)」** 標籤。你可以看到 **CPU 使用率 (CPU Utilization)** 的折線圖正在同步飆升。
        3.  **AWS 觀察點 2 - EC2 ASG**：當 Pod 數量多到節點放不下時，`Cluster Autoscaler` 會觸發 AWS **Auto Scaling Group**。進入 **EC2 -> Auto Scaling Groups**，你會看到「期望容量 (Desired Capacity)」自動增加，並啟動新的 EC2 實例。
        4.  **🏆 資深亮點 (HPA 擴縮容震盪控制)**：*「您可能會注意到我的 HPA 設定檔中使用了 v2 版本的 `behavior` 區塊。在真實生產環境中，流量經常是突發且不穩定的。如果沒有設定 `stabilizationWindowSeconds` (冷卻時間)，Pod 會隨著流量波動頻繁地建立與刪除，這稱為『震盪 (Thrashing)』。我透過精細設定這個參數，確保了擴容迅速、縮容平穩，保護了底層節點的穩定性。」*
        5.  **面試總結金句**：*「這套架構實現了從應用程式壓力到雲端硬體資源的完全自動化連動，大幅降低了維運成本並提升了業務穩定性。」*

---

## 🎭 場景二：金絲雀發布 (Canary Rollout) - P0 核心
**展示內容**：模擬「錯誤版本上線 -> 秒級回滾 -> 正確版本上線 -> 漸進式放量」。

> [!TIP]
> **演示前置作業 (環境大掃除)**：
> 執行以下指令重置環境，確保 Revision 從 #1 開始，並避免 HPA 干擾副本數：
> `kubectl delete rollout ecommerce-backend --ignore-not-found`
> `kubectl delete hpa ecommerce-hpa --ignore-not-found`
> `kubectl apply -f k8s/02-rollout.yaml`

1.  **檢查初始狀態**：
    *   指令：`.\bin\kubectl-argo-rollouts.exe get rollout ecommerce-backend -w`
    *   **意義**：確認目前只有一個穩定版本 (Revision 1)。

2.  **⚡ 階段 A：模擬「故障」版本上線**：
    *   **指令**：`.\bin\kubectl-argo-rollouts.exe set image ecommerce-backend backend=stefanprodan/podinfo:9.9.9-error`
    *   **觀察**：`.\bin\kubectl-argo-rollouts.exe get rollout ecommerce-backend -w`
    *   **面試台詞**：*"現在我模擬一個情境：工程師不小心推送了錯誤的映像檔標籤。在傳統部署中這會導致服務中斷，但在 Canary 模式下，我們只影響了 20% 的 Canary 流量，剩餘 80% 的用戶依然能正常訪問穩定版本。"*

3.  **⚡ 階段 B：秒級回滾 (Rollback)**：
    *   **指令**：`.\bin\kubectl-argo-rollouts.exe undo ecommerce-backend`
    *   **現象**：系統會立刻停止錯誤版本的發布，並將所有流量導回舊有的穩定版。
    *   **面試台詞**：*"發現錯誤後，我不需要手動去改 YAML，一個 undo 指令就能實現秒級回滾，將爆炸半徑降到最低。"*

4.  **⚡ 階段 C：正確版本上線 (v6.3.0)**：
    *   **指令**：`.\bin\kubectl-argo-rollouts.exe set image ecommerce-backend backend=stefanprodan/podinfo:6.3.0`
    *   **現象**：觀察流量再次停在 20% (Step 1/5)。
    *   **面試台詞**：*"現在我們推送修正後的版本。系統再次進入 Canary 觀察期，我們確認 20% 的測試流量一切正常後，再進行手動晉升。" *

5.  **⚡ 階段 D：全量推動 (Promote)**：
    *   **指令**：`.\bin\kubectl-argo-rollouts.exe promote ecommerce-backend`
    *   **意義**：確認無誤後，信心滿滿地將新版本推向 100%。

---

## 🎭 場景三：政策治理 (Governance / Kyverno) - P0 核心
**展示內容**：防止工程師「誤操作」導致的安全漏洞。

> [!TIP]
> **環境大掃除 (重複演示前必做)**：
> ```powershell
> # 1. 先移除舊 Policy（讓步驟 1 的「安裝政策」更有戲劇感）
> kubectl delete clusterpolicy disallow-privileged-containers --ignore-not-found
> 
> # 2. [關鍵！] 必須先刪除 bad-pod！
> # Kyverno 只攔截「新建立」的資源，若 Pod 已存在則 apply 回傳 unchanged
> # 不會觸發 Admission Webhook，導致 Demo 失效！
> kubectl delete pod test-nginx bad-pod-security-violation --ignore-not-found
> 
> # 3. 等待確認 Pod 已完全消失後再繼續
> kubectl get pod bad-pod-security-violation 2>$null; echo "Pod 已清除，可以開始 Demo"
> ```

1.  **安裝安全政策**：`kubectl apply -f k8s/07-kyverno-policy.yaml`
    *   **⚠️ 注意**：這建立的是 `ClusterPolicy`（法條），**不是 Pod**，不會有容器跑起來。
    *   **確認政策已生效**：
        ```powershell
        kubectl get clusterpolicy disallow-privileged-containers
        # 確認 READY = True 才代表攔截功能已啟動！
        ```
        預期輸出：`READY = True`、`ADMISSION = true`
2.  **嘗試「黑客」操作 (特權容器)**：`kubectl apply -f k8s/03-bad-pod.yaml`
3.  **進階嘗試 (非法映像檔來源)**：
    *   指令：`kubectl run test-nginx --image=nginx`
    *   預期結果：報錯 `不允許使用未經授權的映像檔來源`。
4.  **🏆 資深亮點展示 (防禦深度與高可用大局觀)**：
    *   **面試金句 1 (防禦深度)**：*「順帶一提，許多初階的 Policy 會漏掉 `initContainers`，導致攻擊者可以把特權設定藏在初始化容器裡繞過檢查。我們的 Policy 同時掃描了主容器與初始化容器，真正做到滴水不漏。」*
    *   **面試金句 2 (高可用大局觀)**：*「另外，身為平台維運者不能只顧著擋人。我的 Policy 裡特別排除了 `kube-system` 系統命名空間。因為 K8s 底層的網路或儲存外掛本來就需要特權模式，如果不設白名單，嚴格的 Policy 會誤殺系統核心元件導致叢集崩潰。這是我在設計資安政策時，對於安全與系統高可用性平衡的考量。」*
4.  **✅ 收尾驗證 (必做！面試必說)**：
    ```powershell
    kubectl get pod
    # 預期結果：No resources found in default namespace.
    # 這証明了兩個違規 Pod 都沒有被建立！
    ```
    *   **面試金句**：*「你可以看到 Namespace 是完全乾淨的，兩個試圖違規的 Pod 在 API 層就被攔截，根本沒有機會被調度到節點上。這就是 Kyverno Admission Webhook 的威力。」*
5.  **預期結果**：看到 `Forbidden: disallow-privileged-containers` (特權) 或來源錯誤。
4.  **🔍 技術原理 (面試核心重點)**：
    *   **Admission Webhook (准入控制)**：Kyverno 會攔截 K8s API 的所有請求。當您嘗試建立 Pod 時，API Server 會詢問 Kyverno：「這符合規定嗎？」
    *   **左移資安 (Shift-left Security)**：資安不再是部署後才掃描，而是在**部署當下 (Admission Time)** 直接擋掉。
    *   **Policy as Code**：我們將企業的安全準則 (例如：禁止特權容器、限制映像檔來源) 轉化為可被 Git 管理的代碼，實現自動化治理。

    #### 🛠️ Kyverno 擋關三部曲 (運作流程)：
    1. **建立政策**：部署 `07-kyverno-policy.yaml`，手冊寫明「禁止 `privileged: true`」。
    2. **提交請求**：工程師執行 `kubectl apply -f 03-bad-pod.yaml`。
    3. **海關攔截**：K8s API Server 問 Kyverno：「這 Pod 符合安全規定嗎？」
    4. **拒絕入境**：Kyverno 看到違規，回傳 **"Forbidden!"**，Pod 完全不會被建立。
5.  **面試台詞**：*"這就是 Policy as Code。我們將資安準則直接寫入 K8s API 核心，從根源杜絕不安全的容器進入叢集。"*

---

## 🎭 場景四：雲端存儲持久化 (EBS Storage)
**展示內容**：證明 K8s Pod 壞掉後，資料「不會不見」。

> [!TIP]
> **環境大掃除 (重複演示前必做)**：
> 請確保刪除前一場景的殘留，**更重要的是確認沒有舊的 `ebs-test-pod` 活著**，否則 `ReadWriteOnce` 的硬碟會被舊 Pod 佔用，導致新 Pod 卡在 Pending！
> ```powershell
> kubectl delete pod bad-pod-security-violation test-nginx ebs-test-pod-a ebs-test-pod-b --ignore-not-found
> ```

1.  **部署測試 Pod A 並寫入資料**：
    *   `kubectl apply -f demo-pods/ebs-test-pod-a.yaml`
    *   **驗證資料寫入**：`kubectl exec ebs-test-pod-a -- cat /data/secret.txt` (會看到「總營收一千萬」)
2.  **強行殺掉 Pod**：`kubectl delete pod ebs-test-pod-a`
3.  **部署測試 Pod B 驗證資料依舊存在**：
    *   `kubectl apply -f demo-pods/ebs-test-pod-b.yaml`
    *   **驗證資料讀取**：`kubectl exec ebs-test-pod-b -- cat /data/secret.txt`
4.  **面試金句**：*"透過 AWS EBS CSI Driver，我們實現了數據與計算的分離。即使 Pod 被刪除，雲端硬碟仍會自動掛載回新節點，確保企業核心數據不丟失。" *
5.  **🏆 資深亮點展示 (雲原生存儲架構)**：
    *   **面試金句 1 (跨可用區感知)**：*「在我的 `StorageClass` 設定中，我特別使用了 `WaitForFirstConsumer`。因為 EBS 是綁定特定可用區 (AZ) 的。如果設定成立即建立，硬碟可能會建在 AZ-A，但 Pod 卻被排程到 AZ-B，導致永遠無法掛載。這個設定能確保 K8s 調度器先決定 Pod 落在哪個 Node，再通知 AWS 於『同一個 AZ』建立硬碟，這是多可用區高可用架構的必備設定。」*
    *   **面試金句 2 (存儲選型)**：*「這次 Demo 我選用 EBS，它的特性是 `ReadWriteOnce (RWO)`，適合資料庫這類需要獨佔高效能 IOPS 的應用。如果在真實場景中遇到多個 Pod 需要『同時讀寫』同一份檔案（例如共用的圖片庫），我就會改用 AWS EFS 搭配 `ReadWriteMany (RWX)` 的設定。這展現了根據業務需求選擇正確存儲底層的能力。」*
6.  **🧹 收尾清理**：
    *   **指令**：`kubectl delete pod ebs-test-pod-b --ignore-not-found`
    *   **意義**：釋放 EBS 硬碟綁定，保持環境乾淨。

---

## 🎭 場景五：資安漏洞自動掃描 (Trivy)
1.  **指令**：`kubectl get vulnerabilityreports -A`
2.  **預期結果**：你會看到滿滿的系統元件（如 `kube-system` 或 `kyverno`）的掃描報告。這證明了即使你在 `default` 沒有部署應用，平台也已經在自動防護了。
3.  **面試金句 1 (Runtime Scanning)**：*「透過部署 Trivy Operator，我們將資安掃描 (Image Scanning) 從 CI pipeline 延伸到了 Kubernetes 運行時 (Runtime)。只要任何 Pod 跑在這個叢集上，Trivy 就會在背景自動掃描它的已知漏洞 (CVE)。」*
4.  **進階指令 (查看漏洞細節)**：
    ```powershell
    # 隨便挑一個報告來看細節 (這裡以 coredns 為例)
    kubectl get vulnerabilityreports replicaset-coredns-6b8858d7f5-coredns -n kube-system -o yaml | Select-String -Pattern "vulnerabilityID|severity" | Select-Object -First 10
    ```
5.  **🏆 資深亮點展示 (DevSecOps 落地藍圖)**：
    *   **面試金句 2 (告警與阻擋)**：*「在真實的生產環境中，只產出報告是不夠的。我的下一步架構規劃是：第一，讓 Prometheus 收集 Trivy 的 Metrics 建立 Grafana 儀表板，當出現 Critical 漏洞時自動發送 Slack 告警。第二，將 Trivy 與我們剛剛演示的 Kyverno 聯動，如果 Image 包含未修復的高危漏洞，Kyverno 將直接在 Admission 階段阻擋部署，實現真正的 DevSecOps 閉環 (Closed Loop)。」*

---

## 🎭 場景六：DevSecOps CI 管道 (GitHub Actions)
**展示內容**：展示「左移資安 (Shift-Left)」，不用敲任何 K8s 指令，純展示瀏覽器畫面。

> [!TIP]
> **清潔與準備說明**：
> 本場景為純網頁展示，無須任何 K8s 前置安裝，展示完畢後亦**無須任何清潔動作**。

1.  **展示 GitHub Actions 畫面**：
    *   **操作**：打開瀏覽器進入您的 GitHub 專案 -> 點擊 **Actions** 頁籤。
    *   **展示重點 1 (`terraform-ci.yml`)**：點開一個成功的跑過的流程。*"我們所有的 IaC 代碼在合併前，都會自動經過 Terraform 格式化檢查與驗證，確保不會把語法錯誤的配置推上線。"*
    *   **展示重點 2 (`security-scan.yml`)**：*"同時我們也整合了 Trivy 資安掃描在 CI 階段，提早抓出程式碼的潛在漏洞。"*
2.  **🏆 面試金句 (左移資安)**：*「傳統維運往往上線後才發現漏洞。我將 Terraform 檢查與靜態掃描整合進 GitHub Actions，實現真正的『左移資安』，讓問題在 PR 階段就被攔截，大幅減少修復成本。」*

---

## 🎭 場景七：GitOps 持續交付 (Argo CD) - 🌟 破壞性修復展示
**展示內容**：展示 GitOps 最高境界：「配置偏移自動修復 (Drift Detection)」。

> [!TIP]
> **前置準備 (大掃除與安裝)**：
> 1. 確保您有執行過更新版的 `.\bootstrap-platform.ps1` 來安裝 Argo CD。
> 2. **【清潔舊有資源】** 為了讓 Argo CD 完整展現「從無到有」的部署威力，請先刪除前面手動建立的舊資源：
>    `kubectl delete rollout ecommerce-backend --ignore-not-found`
>    `kubectl delete svc ecommerce-svc --ignore-not-found`
> 3. **【綁定 GitOps】** 接著執行：`kubectl apply -f k8s/08-argo-application.yaml` 將本專案交給 Argo CD 管理。

1.  **登入 Argo CD 視覺化介面**：
    *   **指令 1 (獲取密碼)**：
        `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | % { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }`
    *   **指令 2 (開啟對外連線)**：
        `kubectl port-forward svc/argocd-server -n argocd 8080:443`
    *   **操作**：打開瀏覽器前往 `https://localhost:8080`，帳號 `admin`，密碼為剛才獲取的字串。展示畫面上綠色打勾的 `ecommerce-app`。
2.  **💪 實戰破壞展示 (Drift Detection)**：
    *   **解說台詞**：*"Argo CD 主動監聽 GitHub。一旦發現 YAML 變更，就會自動拉取並套用。Git 是唯一的真相來源。現在我來模擬有人惡意或誤操作，刪除線上資源。"*
    *   **破壞指令** (開另一個終端機執行)：`kubectl delete svc ecommerce-svc`
    *   **觀察與高潮**：切換回 Argo CD 介面，您會看到狀態瞬間變成黃色的 `Out of Sync`，接著 Argo CD 會在幾秒內**「自動把 Service 重建回來」**，並恢復綠色打勾。
3.  **🏆 面試金句 (配置偏移)**：*「這就是 Argo CD 的自我修復能力。如果有人不按程序手動改了設定，系統會自動將其覆蓋回 Git 上定義的狀態。徹底解決了維運界最痛的『配置偏移 (Configuration Drift)』問題。」*

---

## 🎭 場景八：底層節點安全強化 (Ansible Node Hardening)
**展示內容**：展現您除了 K8s，也精通「作業系統 (OS)」層級的自動化配置。

> [!TIP]
> **清潔與準備說明**：
> 本場景主要展示腳本開發與架構觀念，沒有在 K8s 中產生新資源。展示完畢後**無須任何清潔動作**。

1.  **展示 Ansible 腳本與驗證**：
    *   **操作**：打開 VSCode 秀出 `ansible/node-hardening.yml`。
    *   **指令 (本地跑語法檢查模擬)**：在終端機執行 `ansible-playbook ansible/node-hardening.yml --syntax-check` (需安裝 Ansible，若無安裝則純解釋檔案即可)。
2.  **解說 IaC 工具的職責邊界**：
    *   **面試台詞**：*"雖然 K8s 提供容器隔離，但底層 EC2 節點的 OS 安全同樣重要。我使用 Ansible 進行 Node Hardening，例如關閉不必要的服務、優化 TCP 參數。"*
3.  **🏆 面試金句 (架構分工)**：*「各個 IaC 工具職責明確：Terraform 負責『把房子蓋起來』，Ansible 負責『把房子的鎖裝好 (OS 合規)』，K8s 讓『應用程式住進去』。這三者結合才是生產標準的雲原生基礎設施。」*

---

## 🧹 結束清理 (重要：防止 AWS 卡死與額外扣款)
> [!WARNING]
> **絕對不能直接跑 `terraform destroy`！**
> 必須先用 `kubectl` 刪除 LoadBalancer、Ingress 與雲端硬碟，否則 AWS VPC 會因為有殘留的網卡 (ENI) 與安全群組 (Security Group) 而無法刪除（卡死報錯），且殘留的 EBS 硬碟會持續扣款！

1.  **清掃 K8s 產生的雲端資源 (NLB, ALB 與 EBS)**：
    ```powershell
    # 0. 【極度重要】如果有展示 Argo CD，必須先砍掉 Application！
    # 否則 Argo CD 的 Self-Heal 機制會像殭屍一樣把您剛刪掉的 LoadBalancer 復活，導致 AWS 資源卡死！
    kubectl delete -f k8s/08-argo-application.yaml --ignore-not-found
    
    # 1. 刪除服務以釋放 AWS NLB (Network Load Balancer)
    kubectl delete -f k8s/03-service.yaml --ignore-not-found
    
    # 2. 刪除 Ingress 以釋放 AWS ALB (如果有練習到這塊的話)
    kubectl delete -f k8s/10-ingress.yaml --ignore-not-found
    
    # 3. 刪除所有的 PVC 以釋放 AWS EBS 實體硬碟 (防止持續扣款)
    kubectl delete pvc --all --ignore-not-found
    ```
2.  **等待 1~2 分鐘**，確保 AWS 後台的 LoadBalancer 已經完全消失。
3.  **執行基礎設施銷毀**：
    ```powershell
    terraform destroy -auto-approve
    ```

    > [!NOTE]
    > **🔍 技術原理解析：為什麼要在 `terraform destroy` 前手動刪除 PVC 與 Service？ (面試加分題)**
    > 這是 Terraform 與 Kubernetes 結合時常見的「雷點 (Gotcha)」。面試時若能主動點出，會展現深厚的實戰經驗：
    > *「我刻意手動清除了 Service (NLB) 與 PVC (EBS)，是因為它們跨越了 K8s，向底層 AWS 索取了『叢集外』的實體資源。」*
    > *「以 PVC 為例，如果直接執行 `terraform destroy`，Terraform 會粗暴地把 EKS 節點砍掉。這導致負責去 AWS 砍掉磁碟區的 **AWS EBS CSI Driver** 也跟著陣亡了，來不及執行清理。結果就是 Kubernetes 裡的資源雖然消失，但 AWS 後台的 EBS 磁碟區卻變成了『孤兒 (Orphaned Resources)』，持續計費且難以追蹤。」*
    > *「因此，標準流程必須是在叢集還活著的時候，先讓 Kubernetes 控制器 (CSI Driver / AWS Load Balancer Controller) 有時間呼叫 AWS API 刪除實體資源。確認乾淨後，再交由 Terraform 執行基礎設施的銷毀。這展現了我對 IaC 邊界與 Kubernetes 動態資源生命週期的深刻理解。」*

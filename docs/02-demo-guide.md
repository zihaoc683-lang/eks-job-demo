# 🚀 EKS 平台工程演示手冊

本手冊為本專案的主線實戰展示，設計目標：**30 分鐘內流暢展示 EKS 核心價值**。每個步驟均包含操作指令、技術說明及架構解析。

> [!NOTE]
> **📚 專案文件導覽 (Index)**
> - [01. 專案架構與技術決策](01-project-architecture.md) (核心文檔)
> - [02. 平台工程演示手冊](02-demo-guide.md) (您目前所在位置)
> - [03. SRE 故障排查與災難復原手冊](03-sre-runbook.md) (架構穩健性)
> - [04. 雲端成本優化分析](04-cost-analysis.md) (FinOps)
> - [05. 技術架構常見問題與決策解析](05-technical-faq.md) (架構深度)

---

## <mark>🛠️ 準備階段 (絕對不可跳過 ⚠️)</mark>

> [!CAUTION]
> **【警告：所有情境的共同前提】**
> 無論您今天要展示場景一還是場景九 (⚠️ 目前未完成實作)，**底下的 0.1 到 0.3 步驟絕對不能跳過！**
> 如果您剛跑完 `terraform apply` 重建叢集，您的叢集是完全空白的。跳過這些步驟會導致：
> 1. `kubectl` 報錯 `no such host` (未更新憑證)。
> 2. 部署 K8s YAML 時報錯 `no matches for kind` (未安裝 Argo CD 或 Kyverno 的 CRD)。

### 0.0 環境檢查與身份驗證 (Connectivity)
*   **指令**：`aws sts get-caller-identity`
*   **意義**：確認目前終端機已正確連線至 AWS 帳號，避免因憑證過期導致 Demo 中斷。

### <mark>0.1 基礎設施建置 (IaC)</mark>
*   **📂 涉及檔案**：`*.tf` (主結構定義)
*   **指令**：
    1. `terraform init`
    2. `terraform apply -auto-approve`
    *(若叢集已建好可跳過此步驟)*
*   **意義**：自動化建立 VPC 網路、EKS 叢集與必要的 IAM 權限。

### <mark>0.2 取得叢集控制權 (Connectivity Upgrade) 🔑</mark>
*   **指令**：`aws eks update-kubeconfig --region ap-northeast-1 --name ecommerce-eks-demo`
*   **檢查**：`kubectl get nodes` (確認所有 Node 狀態為 **Ready**)
*   **意義**：將雲端 EKS 的連線憑證下載至本地。**每次重建叢集後必跑！**

### <mark>0.3 平台引導 (Bootstrap) 🚀</mark>
*   **📂 涉及檔案**：`bootstrap-platform.ps1`
*   **指令**：`.\bootstrap-platform.ps1`
*   **意義**：一鍵佈署「維運鐵三角」，為空白的叢集注入「靈魂」。

#### 🔍 小白也能懂：這個腳本到底裝了什麼？

| 安裝組件 | 形象化比喻 | 實質作用 (為什麼需要？) | 安裝位置 (Namespace) |
| :--- | :--- | :--- | :--- |
| **Metrics Server** | **叢集的溫度計** | 監控 Pod 的 CPU/記憶體。**沒有它，自動擴縮 (HPA) 就會失效。** | `kube-system` |
| **Argo Rollouts** | **高級發布官** | 實施金絲雀發布。讓新版本可以只給 10% 用戶測試，沒問題再全開。 | `argo-rollouts` |
| **Kyverno** | **叢集的交通警察** | 設定安全政策。自動攔截不符合安全規範（如特權容器）的請求。 | `kyverno` |
| **Trivy Operator** | **資安掃描儀** | 自動掃描運行中的 Pod 是否有已知漏洞 (CVE)。 | `trivy-system` |
| **Argo CD** | **叢集管理管家** | 實踐 GitOps。讓叢集狀態永遠跟 GitHub 同步，防止人為亂改。 | `argocd` |
| **EBS Storage** | **雲端硬碟櫃** | 設定 StorageClass。讓 Pod 壞掉重啟後，資料還能從 AWS 存回來。 | `default` (SC) |

> [!TIP]
> **💡 為什麼不直接用 Terraform 裝？**
> 雖然 Terraform 也能裝，但透過這個腳本，我們可以：
> 1. **極速部署**：將原本需要 20 分鐘的雲端等待縮短至 3 分鐘。
> 2. **展現自動化引導 (Bootstrapping) 能力**：透過腳本實現全自動化平台建置，減少人為操作風險。

---

## 🎭 場景一：自癒與自動擴縮 (Self-Healing & HPA)
**📂 涉及檔案**：`k8s/02-rollout.yaml`, `k8s/03-service.yaml`, `k8s/04-hpa.yaml`
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

    *   **🛑 收尾清理**：
        ```powershell
        # 1. 在壓測視窗按下 Ctrl + C 停止指令
        # 2. 為確保資源釋放，執行清理指令：
        kubectl delete pod load-generator --ignore-not-found
        
        # 3. 觀察 Pod 數量是否自動縮回 2 個 (約需等待 30 秒)
        ```
    *   **🔍 技術原理與 AWS 聯動 (技術原理)**：
        1.  **K8s 監控層**：`Metrics Server` 採集數據，`HPA` 根據公式 `ceil[目前副本數 * (目前數據 / 目標數據)]` 決定擴容。
        2.  **AWS 觀察點 1 - EC2 控制台 (保證成功)**：進入 AWS Console -> **EC2** -> **執行中實例**。選中你的 EKS Node，點擊下方的 「監控 (Monitoring)」 標籤。你可以看到 **CPU 使用率 (CPU Utilization)** 的折線圖正在同步飆升。
        3.  **AWS 觀察點 2 - EC2 ASG**：當 Pod 數量多到節點放不下時，`Cluster Autoscaler` 會觸發 AWS **Auto Scaling Group**。進入 **EC2 -> Auto Scaling Groups**，你會看到「期望容量 (Desired Capacity)」自動增加，並啟動新的 EC2 實例。
        4.  **🔍 進階技術說明（HPA 震盪控制）**：「您可能會注意到我的 HPA 設定檔中使用了 v2 版本的 `behavior` 區塊。在真實生產環境中，流量經常是突發且不穩定的。如果沒有設定 `stabilizationWindowSeconds` (冷卻時間)，Pod 會隨著流量波動頻繁地建立與刪除，這稱為『震盪 (Thrashing)』。我透過精細設定這個參數，確保了擴容迅速、縮容平穩，保護了底層節點的穩定性。」
        5.  **🔍 進階技術說明（雙層擴展架構：公寓與住客）**：「這是我架構圖中標註『EC2 擴展』的核心邏輯。我們可以把 EKS 想像成一個『公寓與住客』的關係：
            *   **Pod 擴展 (HPA)**：這就像是公寓裡突然湧入大量住客，我們需要開更多的『房間 (Pods)』。
            *   **EC2 擴展 (Cluster Autoscaler)**：當住客多到連公寓的樓層都蓋滿了，`Cluster Autoscaler` 就會偵測到有住客在排隊 (Pending Pods)，進而自動去 AWS 叫出一台新的 **EC2 實例 (Node)**。
            *   這種由內而外 (Pod -> Node) 的連動，確保了系統在流量高峰時，能從應用層到硬體層實現完全自動化的彈性增長。」
        6.  **架構價值總結**：「這套架構實現了從應用程式壓力到雲端硬體資源的完全自動化連動，大幅降低了維運成本並提升了業務穩定性。」

---

## 🎭 場景二：金絲雀發布 (Canary Rollout) - P0 核心
**📂 涉及檔案**：`k8s/02-rollout.yaml`
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
    *   📢 架構介紹：現在我模擬一個情境：工程師不小心推送了錯誤的映像檔標籤。在傳統部署中這會導致服務中斷，但在 Canary 模式下，我們只影響了 20% 的 Canary 流量，剩餘 80% 的用戶依然能正常訪問穩定版本。

3.  **⚡ 階段 B：秒級回滾 (Rollback)**：
    *   **指令**：`.\bin\kubectl-argo-rollouts.exe undo ecommerce-backend`
    *   **現象**：系統會立刻停止錯誤版本的發布，並將所有流量導回舊有的穩定版。
    *   📢 架構介紹：發現錯誤後，我不需要手動去改 YAML，一個 undo 指令就能實現秒級回滾，將爆炸半徑降到最低。

4.  **⚡ 階段 C：正確版本上線 (v6.3.0)**：
    *   **指令**：`.\bin\kubectl-argo-rollouts.exe set image ecommerce-backend backend=stefanprodan/podinfo:6.3.0`
    *   **現象**：觀察流量再次停在 20% (Step 1/5)。
    📢 架構介紹：現在我們推送修正後的版本。系統再次進入 Canary 觀察期，我們確認 20% 的測試流量一切正常後，再進行手動晉升。
5.  **⚡ 階段 D：全量推動 (Promote)**：
    *   **指令**：`.\bin\kubectl-argo-rollouts.exe promote ecommerce-backend`
    *   **意義**：確認無誤後，信心滿滿地將新版本推向 100%。

6.  **🧹 收尾清理**：
    *   **指令**：
        ```powershell
        kubectl delete rollout ecommerce-backend --ignore-not-found
        kubectl delete svc ecommerce-svc --ignore-not-found
        ```
    *   **意義**：清除 Canary 部署資源，避免影響下一個場景的展示。

---

## 🎭 場景三：政策治理 (Governance / Kyverno) - P0 核心
**📂 涉及檔案**：`k8s/07-kyverno-policy.yaml`, `k8s/03-bad-pod.yaml`
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
4.  **🔍 進階技術說明（防禦深度與高可用考量）**：
    *   📢 架構介紹（防禦深度）：「順帶一提，許多初階的 Policy 會漏掉 `initContainers`，導致攻擊者可以把特權設定藏在初始化容器裡繞過檢查。我們的 Policy 同時掃描了主容器與初始化容器，真正做到滴水不漏。」
    *   📢 架構介紹（高可用考量）：「另外，身為平台維運者不能只顧著擋人。我的 Policy 裡特別排除了 `kube-system` 系統命名空間。因為 K8s 底層的網路或儲存外掛本來就需要特權模式，如果不設白名單，嚴格的 Policy 會誤殺系統核心元件導致叢集崩潰。這是我在設計資安政策時，對於安全與系統高可用性平衡的考量。」
4.  **✅ 收尾驗證 (必做)**：
    ```powershell
    kubectl get pod
    # 預期結果：No resources found in default namespace.
    # 這証明了兩個違規 Pod 都沒有被建立！
    ```
    *   📢 架構介紹：「你可以看到 Namespace 是完全乾淨的，兩個試圖違規的 Pod 在 API 層就被攔截，根本沒有機會被調度到節點上。這就是 Kyverno Admission Webhook 的威力。」
5.  **預期結果**：看到 `Forbidden: disallow-privileged-containers` (特權) 或來源錯誤。
4.  **🔍 技術原理 (技術原理)**：
    *   **Admission Webhook (准入控制)**：Kyverno 會攔截 K8s API 的所有請求。當您嘗試建立 Pod 時，API Server 會詢問 Kyverno：「這符合規定嗎？」
    *   **左移資安 (Shift-left Security)**：資安不再是部署後才掃描，而是在**部署當下 (Admission Time)** 直接擋掉。
    *   **Policy as Code**：我們將企業的安全準則 (例如：禁止特權容器、限制映像檔來源) 轉化為可被 Git 管理的代碼，實現自動化治理。

    #### 🛠️ Kyverno 擋關三部曲 (運作流程)：
    1. **建立政策**：部署 `07-kyverno-policy.yaml`，手冊寫明「禁止 `privileged: true`」。
    2. **提交請求**：工程師執行 `kubectl apply -f 03-bad-pod.yaml`。
    3. **海關攔截**：K8s API Server 問 Kyverno：「這 Pod 符合安全規定嗎？」
    4. **拒絕入境**：Kyverno 看到違規，回傳 **"Forbidden!"**，Pod 完全不會被建立。
5.  📢 架構介紹：這就是 Policy as Code。我們將資安準則直接寫入 K8s API 核心，從根源杜絕不安全的容器進入叢集。

6.  **🧹 收尾清理**：
    *   **指令**：
        ```powershell
        # 若要重複演示，建議移除政策以重新展示「安裝過程」
        kubectl delete clusterpolicy disallow-privileged-containers --ignore-not-found
        ```
    *   **意義**：維持環境獨立性。

---

## 🎭 場景四：雲端存儲持久化 (EBS Storage)
**📂 涉及檔案**：`demo-pods/ebs-test-pod-a.yaml`, `demo-pods/ebs-test-pod-b.yaml`
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
4.  **🔍 進階技術說明（雲原生存儲架構）**：

    📢 架構介紹：「透過 AWS EBS CSI Driver，我們實現了數據與計算的分離。即使 Pod 被刪除，雲端硬碟仍會自動掛載回新節點，確保企業核心數據不丟失。」

    📢 架構介紹（跨可用區感知）：「在我的 `StorageClass` 設定中，我特別使用了 `WaitForFirstConsumer`。因為 EBS 是綁定特定可用區 (AZ) 的。如果設定成立即建立，硬碟可能會建在 AZ-A，但 Pod 卻被排程到 AZ-B，導致永遠無法掛載。這個設定能確保 K8s 調度器先決定 Pod 落在哪個 Node，再通知 AWS 於『同一個 AZ』建立硬碟，這是多可用區高可用架構的必備設定。」

    📢 架構介紹（存儲選型）：「這次 Demo 我選用 EBS，它的特性是 `ReadWriteOnce (RWO)`，適合資料庫這類需要獨佔高效能 IOPS 的應用。如果在真實場景中遇到多個 Pod 需要『同時讀寫』同一份檔案（例如共用的圖片庫），我就會改用 AWS EFS 搭配 `ReadWriteMany (RWX)` 的設定。這展現了根據業務需求選擇正確存儲底層的能力。」

6.  **🧹 收尾清理**：
    *   **指令**：`kubectl delete pod ebs-test-pod-b --ignore-not-found`
    *   **意義**：釋放 EBS 硬碟綁定，保持環境乾淨。

---

## 🎭 場景五：資安漏洞自動掃描 (Trivy Operator)
**📂 涉及檔案**：(平台組件，由 Bootstrap 腳本安裝)

> [!TIP]
> **💡 演示小撇步 (Pro-tips)：**
> 1. **耐心等待掃描完成**：Trivy Operator 在剛安裝完後的 1-3 分鐘內可能還在啟動掃描任務，此時執行指令可能會看到 `No resources found`。若遇到此情況，請向審閱者說明「掃描器正在進行初次全盤掃描」，稍等片刻即可。
> 2. **關於 `monitoring` 命名空間**：如果您尚未部署 Prometheus 等監控組件，`-n monitoring` 會顯示查無資源。這正是「有 Pod 才有掃描」的精確表現，也證明了報告是即時且真實的。

### 💡 運作原理 (Working Principle)
*   **事件驅動 (Event-driven)**：Trivy Operator 監聽 K8s API，一旦有新 Pod 生成，立即觸發掃描任務 (Scan Job)。
*   **資源化報告**：掃描結果直接轉化為 K8s 的 **Custom Resource (CRD)**，讓 SRE 能用原生指令 `kubectl get vulnerabilityreports` 進行審計。
*   **持續監控**：除了初次生成，系統也會定時複查 (預設 24h)，確保發現最新的漏洞 (Zero-day)。

### 演示步驟
1.  **查看全叢集漏洞報告**：
    ```powershell
    kubectl get vulnerabilityreports -A
    ```
2.  **查看特定應用的詳細漏洞 (以 Prometheus 為例)**：
    ```powershell
    kubectl get vulnerabilityreports -n monitoring
    ```
3.  **進階：查看漏洞細節 (以 CoreDNS 為例)**：
    ```powershell
    # 透過 Select-String 過濾出漏洞 ID 與嚴重等級
    kubectl get vulnerabilityreports -n kube-system -o yaml | Select-String -Pattern "vulnerabilityID|severity" | Select-Object -First 15
    ```
4.  📢 **解說詞**：
    > 「我們引入了 Trivy Operator 實現了 **Continuous Security**。這讓資安掃描從 CI 階段延伸到了運行時 (Runtime)。維運人員不需要切換工具，直接透過 `kubectl` 就能掌握全叢集的安全狀態，甚至能細看每一個漏洞的 CVE 編號。這展現了 **Security as Data** 的現代運算思維。」

4.  **🔍 進階技術說明（DevSecOps 藍圖）**：
    > 「在真實生產環境中，我會將 Trivy 與 **Kyverno** 聯動。如果掃描報告顯示包含 Critical 等級的漏洞，政策引擎會自動禁止該 Pod 的執行，實現自動化的安全治理閉環。」

6.  **🧹 收尾清理**：
    *   **說明**：Trivy Operator 為背景監控組件，展示完畢後**無須手動清理**，不影響其他場景運作。

---

## 🎭 場景六：DevSecOps CI 管道 (GitHub Actions)
**📂 涉及檔案**：
*   `.github/workflows/security-scan.yml`：**安全守門員**。運行 Trivy 進行 Container Image 與 IaC 漏洞掃描。
*   `.github/workflows/terraform-ci.yml`：**合規自動化**。整合 Checkov 靜態分析與 Terraform Plan 預覽。
*   `*.tf` & `k8s/*.yaml`：**被動審計對象**。代表「Infrastructure as Code」，是所有安全規則的實踐主體。
**展示內容**：展示「左移資安 (Shift-Left)」，不用敲任何 K8s 指令，純展示瀏覽器畫面。

> [!TIP]
> **清潔與準備說明**：
> 本場景為純網頁展示，無須任何 K8s 前置安裝，展示完畢後亦**無須任何清潔動作**。
> 確認 GitHub Actions 頁面有 ✅ 綠色紀錄後即可開始展示。

> [!TIP]
> **💡 演示小撇步 (Pro-tips)：**
> 1. **看到「紅燈 (Red X)」不要慌**：如果您的 `Terraform CI/CD` 顯示失敗，這反而是展示 **「自動化攔截 (Security Gatekeeping)」** 的最佳機會。您可以說明：「這代表我的 Pipeline 成功抓到了不符合規範的代碼（例如 S3 未加密），並在進入生產環境前將其擋下。」
> 2. **展示重點**：點開失敗的 Job，找出 `Checkov` 掃描結果，展示那些失敗的 `FAILED` 項目，這比單純看綠燈更能展現 DevSecOps 的價�## 🎭 場景九：可觀測性與監控 (Observability / Grafana)
**📂 涉及檔案**：`k8s/09-observability.yaml`
**展示內容**：展示如何透過 GitOps 實現「監控即代碼 (Observability as Code)」，並利用 SRE 黃金訊號進行叢集治理。

### 📂 1. 場景涉及檔案與技術角色
| 檔案路徑 | 角色定位 | 功能詳解 (做了什麼？) |
| :--- | :--- | :--- |
| **`k8s/09-observability.yaml`** | **配置源頭 (GitOps)** | **Argo CD Application**。定義了 `kube-prometheus-stack` 的 Helm 部署參數。 |
| **`monitoring` Namespace** | **監控領地** | 所有監控組件 (Prometheus, Grafana, Exporters) 的存放空間。 |
| **`argocd-server`** | **部署守護者** | 負責監控系統本身的生命週期管理與故障修復。 |

---

### 🧠 2. 核心架構思維：為什麼要用 Argo CD 裝監控？
*   📢 **解說詞**：「場景九我們實踐的是 **『監控即代碼 (Observability as Code)』**。我們不手動執行 Helm 指令，而是將監控系統的規格定義在 Git 中，交由 Argo CD 進行管理。這確保了當叢集規模擴展或重建時，監控系統能自動以完全一致的規格被復原，消除了手動安裝的不確定性。」

---

### 🛠️ 3. 部署與實戰故障排除 (Troubleshooting)

#### Step 1：執行 GitOps 部署
*   **指令**：`kubectl apply -f k8s/09-observability.yaml`

> [!CAUTION]
> **🚨 SRE 實戰經驗：處理巨大的 CRD (Server Side Apply)**
> **現象**：若 Argo CD 顯示 `Sync failed` 且報錯 `Too long: must have at most 262144 characters`。
> **原因**：Prometheus Stack 的定義檔極其龐大，超出了 K8s 預設的 64KB 註解限制。
> **解決方案**：
> 1. 登入 Argo CD -> 點進 `prometheus-stack` -> `APP DETAILS`。
> 2. `SYNC POLICY` -> `EDIT` -> 勾選 **`Server Side Apply`** 並儲存。
> 3. 再次點擊 **`SYNC`**，即可順利綠燈。這展現了處理大規模 K8s 設定檔的專業經驗。

#### Step 2：等待與狀態檢查
*   **檢查指令**：`kubectl get pods -n monitoring -w`
*   **目標**：看到 `prometheus-prometheus-stack-...-0` 出現且為 `Running`。

---

### 📊 4. 深度看板解析 (SRE 黃金訊號展示)

*   **登入指令**：`kubectl port-forward svc/prometheus-stack-grafana -n monitoring 3000:80`
*   **帳密**：`admin` / `admin` (或設定好的固定密碼)

📢 **解說詞 (專業 Talk Track)**：
> 「現在我們進入 Grafana 面板。身為 SRE，我們不只是看數據，我們看的是 **『黃金訊號 (Golden Signals)』**。我特別推薦看這三個面板，它們分別代表了叢集的不同維度：」

1.  **`Kubernetes / Compute Resources / Cluster` (飽和度 Saturation)**：
    *   **觀察重點**：叢集整體的 CPU/Memory 水位。這決定了我們是否需要擴展 AWS EC2 節點。
2.  **`Kubernetes / Compute Resources / Namespace (Pods)` (流量 Traffic & 錯誤 Errors)**：
    *   **觀察重點**：特定應用 (如 Backend) 的資源消耗。這能幫助我們微調 HPA 的觸發閾值，達到成本與穩定性的平衡。
3.  **`Kubernetes / API server` (延遲 Latency & 健康度)**：
    *   **觀察重點**：這是 EKS 控制平面的靈魂。如果 API 響應變慢，代表叢集管理層可能面臨壓力，這是進階維運才具備的洞察力。

---

### 🧹 5. 結束展示與清理
*   **指令**：(Ctrl + C 停止隧道)
*   **資源回收**：`kubectl delete -f k8s/09-observability.yaml --ignore-not-found`
*   **說明**：Argo CD 會自動透過 Cascading Delete 清除所有 50+ 個監控組件，保持環境整潔。
tions，讓安全檢查在工程師提交 PR 的當下就自動執行。這就是所謂的『左移資安 (Shift-Left Security)』——把問題攔在最早、最便宜修復的階段。」

---

## 🎭 場景七：GitOps 持續交付 (Argo CD) - 🌟 破壞性修復展示
**📂 涉及檔案**：`k8s/08-argo-application.yaml` 及 `k8s/base/`, `k8s/overlays/production/`
**展示內容**：展示 GitOps 最高境界：「配置偏移自動修復 (Drift Detection)」與 Kustomize 架構。

> [!NOTE]
> **架構設計亮點：Kustomize (Base & Overlays) 架構**
> 在執行部署前，我們可以看到專案中使用了 `k8s/base/` (公版) 與 `k8s/overlays/production/` (客製化覆蓋版)。
> 傳統部署中，不同環境 (Dev, Prod) 往往需要複製多份 YAML，導致維護困難。透過 Kustomize，我們將共通設定放在 `base`，並在 `overlays` 針對特定環境打上 Patch (例如提高正式機的副本數)。這樣確保了基礎架構的「唯一真相」，大幅提升設定檔的重用性並降低維護風險。Argo CD 將會直接拉取 `production` 的設定進行部署。



> [!TIP]
> **前置準備 (大掃除與安裝)**：
> 1. **【極度重要：推送程式碼】** Argo CD 是直接從您的 GitHub 遠端倉庫拉取設定，**不是讀取您電腦裡的本地檔案**。請確保您已經將所有修改 (包含 `k8s/08-argo-application.yaml`) `git commit` 並 `git push` 上 GitHub，否則 Argo CD 抓不到最新的設定！
> 2. 確保您有執行過更新版的 `.\bootstrap-platform.ps1` 來安裝 Argo CD。
> 3. **【清潔舊有資源】** 為了讓 Argo CD 完整展現「從無到有」的部署威力，請先刪除前面手動建立的舊資源與 ArgoCD 應用（若您是要重複演練）：
>    ```powershell
>    kubectl delete application ecommerce-app -n argocd --ignore-not-found
>    kubectl delete rollout ecommerce-backend --ignore-not-found
>    kubectl delete svc ecommerce-svc --ignore-not-found
>    ```
> 3. **【綁定 GitOps】** 接著執行：`kubectl apply -f k8s/08-argo-application.yaml` (執行後請等待約 30 秒讓 Argo CD 完成同步)。

1.  **登入 Argo CD 視覺化介面**：

    > [!IMPORTANT]
    > **固定密碼**：本專案 admin 密碼已設定為固定值，無需每次查詢。
    > - 密碼：**`ArgoDemo2026!`**
    >
    > 若叢集重建後密碼失效，執行下方「**密碼重設**」區塊還原。

    *   **指令 (開啟對外連線)**：
        ```powershell
        kubectl port-forward svc/argocd-server -n argocd 9090:443
        ```
        > 💡 **為什麼用 9090 而不是 8080？**
        > *   **對外存取 (9090)**：Windows 系統常會佔用 `8080`，因此我們將本地端對應改為 `9090` 以確保 Demo 順利。
        > *   **對內指令 (8080)**：下方的「密碼重設」腳本使用的是 `kubectl exec` 進入 Pod 內部，而在 Pod 內部 Argo CD 預設就是監聽 `8080`。這兩者分別處於「外部隧道」與「內部環境」，因此埠號不同是正常的。
    *   **操作**：打開瀏覽器前往 `https://localhost:9090`，忽略憑證警告，帳號 `admin`，密碼 `ArgoDemo2026!`。展示畫面上綠色打勾的 `ecommerce-app`。

    <details>
    <summary>🔧 密碼重設（叢集重建後才需要執行，平時不用管）</summary>

    > **原理**：用 ArgoCD 自帶的 CLI 改密碼，這是唯一保證 bcrypt hash 正確的方法。

    ```powershell
    # Step 1：取得 argocd-server pod 名稱
    $pod = kubectl -n argocd get pods -l app.kubernetes.io/name=argocd-server --no-headers -o custom-columns=":metadata.name"
    echo "Pod: $pod"

    # Step 2：取得初始密碼（叢集剛建立時的原始密碼）
    $initPwd = (kubectl -n argocd exec $pod -- argocd admin initial-password -n argocd) | Select-Object -First 1
    echo "初始密碼: $initPwd"

    # Step 3：在 pod 內用 CLI 登入
    kubectl -n argocd exec $pod -- argocd login localhost:8080 --insecure --username admin --password $initPwd

    # Step 4：改為固定密碼
    kubectl -n argocd exec $pod -- argocd account update-password --server localhost:8080 --insecure --current-password $initPwd --new-password ArgoDemo2026!

    # Step 5：驗證新密碼可用
    kubectl -n argocd exec $pod -- argocd login localhost:8080 --insecure --username admin --password ArgoDemo2026!
    echo "✅ 密碼重設成功，往後固定使用 ArgoDemo2026! 登入"
    ```

    </details>
2.  **💪 實戰破壞展示 (Drift Detection)**：
    *   📢 架構介紹：Argo CD 主動監聽 GitHub。一旦發現 YAML 變更，就會自動拉取並套用。Git 是唯一的真相來源。現在我來模擬有人惡意或誤操作，刪除線上資源。
    *   **破壞指令** (開另一個終端機執行)：`kubectl delete svc ecommerce-svc`
    *   **觀察與高潮**：切換回 Argo CD 介面，您會看到狀態瞬間變成黃色的 `Out of Sync`，接著 Argo CD 會在幾秒內「自動把 Service 重建回來」，並恢復綠色打勾。
3.  **🔍 技術原理解析（為何會秒恢復？）**：
    *   📢 **架構設計亮點一：GitOps 單一真相來源 (Single Source of Truth)**
        「傳統維運中，K8s 的實際狀態與我們手邊的 YAML 檔很容易脫節。而 GitOps 的核心精神是：『Git 倉庫裡的程式碼，就是環境的唯一真相』。當我們把專案綁定到 Argo CD 後，它就成為了這個真相的守護者。」
    *   📢 **架構設計亮點二：調和迴圈 (Reconciliation Loop)**
        「Argo CD 內部有一個 Controller，它會每 3 分鐘（預設值，也可以設定 webhook 即時觸發）去比對『Git 上的 YAML』與『K8s 實際運行的資源』。這就像是會計在對帳一樣。」
    *   📢 **架構設計亮點三：自我修復機制 (Self-Healing)**
        「在剛才的展示中，我手動刪除了 Service。Argo CD 在對帳時立刻發現：『咦？Git 上明明寫著要有這個 Service，為什麼 K8s 裡面沒有？這產生了**配置偏移 (Configuration Drift)**！』。因為我們在 Application 設定中開啟了 `selfHeal: true`，Argo CD 就會毫不猶豫地把遺失的資源重新 apply 回去。這徹底杜絕了工程師圖方便『手動改線上機器卻不改 Code』的壞習慣，確保基礎設施始終與 Git 保持一致。」

4.  **🧹 收尾清理**：
    ```powershell
    # 在執行 port-forward 的終端機視窗按下 Ctrl + C 即可停止
    # 若找不到該視窗，用以下指令強制釋放 9090 port：
    Stop-Process -Id (Get-NetTCPConnection -LocalPort 9090 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess) -Force -ErrorAction SilentlyContinue
    echo "Port 9090 已釋放"
    ```

---

## 🎭 場景八：底層節點安全強化 (Ansible Node Hardening)
**📂 涉及檔案**：`ansible/node-hardening.yml`
**展示內容**：展示如何透過「審計-修復-驗證」SRE 流程，確保 K8s 底層作業系統 (OS) 的安全性與效能。

### 📂 1. 場景涉及檔案與技術角色
| 檔案路徑 | 角色定位 | 功能詳解 (做了什麼？) |
| :--- | :--- | :--- |
| **`ansible/node-hardening.yml`** | **配置源頭 (IaC)** | **Ansible 定義檔**。定義了節點加固的「最終狀態」，包含安全性補丁與內核優化。 |
| **`bin/node-audit.ps1`** | **審計工具 (Audit)** | **偵測指令**。檢查節點目前的 `net.core.somaxconn` 數值。 |
| **`bin/node-fix.ps1`** | **修復工具 (Remediate)** | **執行加固**。模擬 Ansible 行為，即時修復 OS 層級參數。 |
| **`bin/node-reset.ps1`** | **重置工具 (Cleanup)** | **還原環境**。將系統推回不合規狀態以便重新演示。 |
| **`docs/02-demo-guide.md`** | **演示手冊 (Manual)** | **劇本與講稿**。將工具串聯成一個流暢的 SRE 故事線。 |

---

### 🛠️ 2. 準備階段 (環境大掃除)

> [!TIP]
> **環境大掃除 (重複演示前必做)**：
> 為了確保「審計」階段能看到異常數值，請先將參數重置為 Linux 預設值：
> ```powershell
> .\bin\node-reset.ps1
> ```

> [!CAUTION]
> **🚨 排除故障：如果出現「Admission Webhook Denied」報錯？**
> 如果您剛執行完 **場景三 (Kyverno)** 且未清理政策，建立重置容器時會被攔截。這證明了安全政策正在生效！
> **解決方案**：執行 `kubectl delete clusterpolicy disallow-privileged-containers --ignore-not-found` 移除禁令後再繼續。

---

### 🚀 3. 演示流程 (SRE 三部曲)

#### Step 1：🔍 合規性審計 (Audit)
*   📢 **解說詞**：「身為 SRE，我們不能只管容器，底層節點的健康才是穩定的基石。現在我檢查發現節點的 TCP 連線隊列參數僅為預設值，這在高併發下會導致丟包。」
*   **指令**：
    ```powershell
    .\bin\node-audit.ps1
    ```
*   **預期現象**：看到 `net.core.somaxconn = 128` (或 `>>> Current Node Setting:` 下方顯示 128)。

#### Step 2：🛠️ 自動化修復 (Remediation)
*   📢 **解說詞**：「在生產環境中，我們使用 **Ansible** 進行自動化配置管理。現在我執行修復腳本，模擬 Ansible 將加固參數 `1024` 即時套用到所有節點。」
*   **指令**：
    ```powershell
    .\bin\node-fix.ps1
    ```

#### Step 3：✅ 最終驗證 (Verification)
*   📢 **解說詞**：「修復完成後，我們進行最後的審計驗證。這是一個完整的 **Audit-Remediate-Verify** 閉環，確保系統符合預期。」
*   **指令**：
    ```powershell
    .\bin\node-audit.ps1
    ```
*   **預期現象**：看到 `net.core.somaxconn = 1024`。

---

### 🧠 4. SRE 深度技術解析 (演示重點)

#### 為什麼選擇 `net.core.somaxconn` 作為加固目標？
*   **技術原理**：它定義了 Socket 監聽隊列的上限。預設 `128` 在爆量流量下會直接 Drop 新的連線。提升至 `1024` 是確保叢集「生產就緒 (Production Ready)」的標準動作。
*   **架構價值**：展現了對 Linux 核心參數的掌握，以及透過 IaC 消除「配置偏移 (Drift)」的能力。

#### ❓ 技術 Q&A：為什麼執行完會出現 `pod ... deleted` 訊息？
*   **SRE 實踐**：這代表 `--rm` 參數正在生效。對於這類一次性工具，自動刪除 Pod 是為了**保持叢集整潔 (Cluster Hygiene)**。
*   **技術亮點**：這展現了 **「無代理程式 (Agentless)」** 的維運思維，隨插即用、用完即丟，不佔用 K8s API 資源。

#### 💡 技術細節提示 (關於 Pod 被刪除的回答)：
> 「這是我在腳本中設定的自動清理機制。我們使用 **Ephemeral (臨時性) Pod** 來執行維運任務，並透過 `--rm` 參數確保任務結束後立即釋放資源。這體現了我們在平台治理中對『環境整潔度』與『自動化生命週期管理』的重視。」

---

### 🧹 5. 收尾清理
*   **說明**：
    1. **資源釋放**：偵錯 Pod 已自動刪除。
    2. **狀態保留**：保留加固狀態證明演示成功。若需重測請執行 `.\bin\node-reset.ps1` 即可。



## 🎭 場景九：可觀測性與監控 (Observability / Grafana) (⚠️ 未完成實作)
> [!WARNING]
> **🚧 實作中 (Under Construction)**
> 此場景之監控組件與儀表板尚在整合測試中，暫不建議於正式演示中使用。

> [!IMPORTANT]
> **📢 場景九前置準備：Argo CD 核心檢查 (Demo 順暢關鍵)**
>
> **為什麼這裡需要 Argo CD？**
> 場景九並非手動安裝，而是實踐 **「監控即代碼 (Observability as Code)」**。我們透過 Argo CD 統一管理複雜的 Prometheus Stack，確保監控組件的狀態與 GitHub 完全同步，避免人為設定偏移。
>
> **1. 執行部署**：`kubectl apply -f k8s/09-observability.yaml`
> **2. 故障排除 (必看 ⚠️)**：
> 由於 Prometheus 的自定義資源 (CRD) 極其龐大，常會超出 K8s 預設的註解限制 (64KB)。若 Argo CD 顯示 `Sync failed`，請務必開啟 **Server Side Apply**：
> *   進入 Argo CD 介面 -> `prometheus-stack` -> `APP DETAILS` -> `SYNC POLICY` -> 勾選 **`Server Side Apply`** -> 儲存並重新 **`SYNC`**。
> **3. 等待機制**：同步開始後需約 **2-3 分鐘**，直到 `kubectl get pods -n monitoring` 看到所有組件為 `Running`。
> **※ 提醒**：若連線斷開，請重新執行 `kubectl port-forward svc/prometheus-stack-grafana -n monitoring 3000:80`。

1.  **登入 Grafana 視覺化介面**：
    *   **指令 (開啟對外連線)**：
        ```powershell
        kubectl port-forward svc/prometheus-stack-grafana -n monitoring 3000:80
        ```
    *   **操作**：打開瀏覽器前往 `http://localhost:3000`。
    *   **帳號密碼**：帳號 `admin`，密碼 `admin` (定義於 `09-observability.yaml` 中)。
2.  **展示內建儀表板 (Dashboards) — 監控要點**：
    *   登入後，點擊左側導覽列的 **Dashboards**。
    *   **推薦優先展示以下三個面板，這最能展現 SRE 的「黃金訊號 (Golden Signals)」監控思維：**
        1.  **`Kubernetes / Compute Resources / Cluster` (最直觀)**：
            *   **技術要點**：監控整個 EKS 叢集的 CPU/Memory 資源水位與健康狀況。
        2.  **`Kubernetes / Compute Resources / Namespace (Pods)` (實務應用)**：
            *   **技術要點**：選擇 `default` 或 `monitoring` 命名空間。配合壓測場景，可即時觀測 Pod 水平擴展 (HPA) 與資源消耗曲線。
        3.  **`Kubernetes / API server` (展現深度)**：
            *   **技術要點**：監控 API Server 的 Request Latency (延遲) 與 Request Rate。這是評估控制平面 (Control Plane) 健康度的關鍵指標。
3.  **架構解說 (Technical Breakdown)**：
    *   📢 **架構介紹**：「在 K8s 中建立監控系統非常繁瑣，所以我選用了業界標準的 `kube-prometheus-stack` Helm Chart，並結合剛才展示的 Argo CD (GitOps) 進行管理。」
    *   📢 **架構介紹**：「大家現在看到的這些儀表板是隨插即用的。Prometheus 在背景會透過 `ServiceMonitor` 自動發現叢集內的新服務並抓取 Metrics。這意味著未來開發團隊部署新微服務時，只要加上簡單的註解，監控指標就會自動進到這個面板中，實現了『可觀測性即代碼 (Observability as Code)』。」
4.  **🧹 結束展示與清理**：
    *   在執行 port-forward 的終端機視窗按下 Ctrl + C 停止連線。
    *   **若找不到該視窗，用以下指令強制釋放 3000 port**：
        ```powershell
        Stop-Process -Id (Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess) -Force -ErrorAction SilentlyContinue
        echo "Port 3000 已釋放"
        ```
    *   **若要確保情境獨立性 (移除監控堆疊)**：
        ```powershell
        # 刪除 Argo CD Application，Argo CD 會自動把 Prometheus 相關資源全部回收
        kubectl delete -f k8s/09-observability.yaml --ignore-not-found
        ```


---

---

## 🎭 場景十：災難復原實戰 (Disaster Recovery / Velero)

### 📂 演示資產清單 (File Inventory)
| 檔案名稱 | 角色 | 說明 |
| :--- | :--- | :--- |
| `bin/dr-demo.ps1` | **模擬引擎** | 封裝了 `init`, `disaster`, `recover` 邏輯，確保復原順序正確。 |
| `demo-pods/ebs-pvc.yaml` | **數據層 (Soul)** | 定義 EBS 磁碟宣告 (PVC)，模擬 Velero 從快照復原的數據載體。 |
| `demo-pods/ebs-test-pod-a.yaml` | **應用層 (Body)** | 定義掛載磁碟的 Pod，內含自動寫入機密資料的模擬腳本。 |

---

### 🟢 第一階段：前期清掃與環境建置 (Pre-cleanup & Setup)

> [!IMPORTANT]
> **為什麼要先清場？**
> 為了避免場景四或其他背景任務 (如 Argo CD) 佔用有限的 ENI IP 資源，開始前請務必執行清場。

1.  **徹底清空戰場**：
    ```powershell
    # 暫停 Argo CD 控制並刪除所有舊部署
    kubectl delete -f k8s/08-argo-application.yaml --ignore-not-found
    kubectl delete rollout --all --ignore-not-found
    .\bin\dr-demo.ps1 clean
    ```

2.  **初始化環境 (Build)**：
    ```powershell
    .\bin\dr-demo.ps1 init
    ```
    *   **檢查**：`kubectl get pod ebs-test-pod-a -w` (等待至 `Running`)。

3.  **寫入測試數據 (The Proof)**：
    ```powershell
    kubectl exec ebs-test-pod-a -- sh -c "echo '機密資料：2026總營收一千萬' > /data/secret.txt"
    ```
    *   📢 **演示說明**：「我們已經在 EBS 磁碟中寫入了關鍵數據，這將作為等一下復原成功的唯一憑證。」

---

### 🔴 第二階段：災難發生與復原演示 (Disaster & Recovery)

1.  **觸發區域級災難**：
    ```powershell
    .\bin\dr-demo.ps1 disaster
    ```
    *   **驗證消失**：`kubectl get pod,pvc ebs-test-pod-a ebs-claim` (應回報 NotFound)。
    *   📢 **演示說明**：「模擬發生了極端故障，我們的應用與磁碟連結已徹底毀滅。現在，我們啟動 SRE 自動化復原程序。」

2.  **執行一鍵復原**：
    ```powershell
    .\bin\dr-demo.ps1 recover
    ```
    *   📢 **演示說明**：「腳本正在執行三層復原：基礎設施對齊 -> Velero 快照恢復 -> Argo CD 邏輯同步。注意看，我們優先復原了數據層 (PVC) 以確保應用啟動不失敗。」

---

### 🔵 第三階段：數據一致性驗證 (Moment of Truth)

1.  **見證奇蹟**：
    ```powershell
    # 等待 Pod Running 後執行
    kubectl exec ebs-test-pod-a -- cat /data/secret.txt
    ```
    *   📢 **演示說明**：「大家看螢幕！資料原封不動地回來了。這體現了我們 **RPO = 0** 的高韌性架構。」

---

### ⚪ 第四階段：後期清理 (Final Cleanup)

1.  **還原環境**：
    ```powershell
    .\bin\dr-demo.ps1 clean
    ```
    *   📢 **結語**：「這套流程證明了我們具備應對區域級災難的能力，將 MTTR 從數小時縮短至不到一分鐘。」


### 🧠 SRE 深度技術解析 (RTO/RPO)
*   📢 **深度解說**：「這個流程體現了我們的 **RPO (復原點目標) 趨近於 0**，因為我們利用了 AWS EBS 的快照機制；同時 **RTO (復原時間目標)** 僅需數分鐘，這歸功於我們將所有配置都 **代碼化 (IaC)** 與 **GitOps 化** 的設計成果。」

---

### 🔍 SRE 實戰診斷：當 Pod 卡在 Pending 時 (Troubleshooting)
如果在執行 `init` 後 Pod 長時間停留在 `Pending`，請執行 `kubectl describe pod ebs-test-pod-a`，您可能會學到以下經典 SRE 案例：

1.  **Too many pods (資源飽和)**：
    *   **現象**：顯示 `0/4 nodes are available: 3 Too many pods`。
    *   **原因**：EKS 小型節點有 Pod 數量上限（受限於 ENI IP 數量）。
    *   **對策**：這正是展示「資源管理」的好機會。您可以說：「因為測試環境資源有限，我現在手動清理不必要的 Demo 資源，這體現了 SRE 對叢集容量 (Capacity) 的掌控。」
2.  **Argo CD 資源爭奪戰 (Self-Healing Competition)**：
    *   **現象**：剛刪掉其他 Pod，空間又立刻被 `ecommerce-backend` 搶走。
    *   **原因**：Argo CD 偵測到狀態不一致，自動修復 (Self-Heal) 了被刪除的應用。
    *   **解決**：暫時刪除 Argo CD Application (`kubectl delete -f k8s/08-argo-application.yaml`)，確保 DR 場景有最高優先權。
3.  **PVC Not Found (復原順序問題)**：
    *   **現象**：Pod 報錯 `persistentvolumeclaim "ebs-claim" not found`。
    *   **原因**：復原時 Pod 比 PVC 先建立，導致 Scheduler 找不到磁碟。
    *   **對策**：修正腳本執行順序，採用「數據優先 (Data-First)」策略。這展現了對 K8s 資源依賴鏈 (Dependency Chain) 的理解。
4.  **Volume Node Affinity Conflict (區域衝突)**：
    *   **原因**：EBS 硬碟屬於「單一可用區 (AZ)」資源。如果 Pod 被調度到不含該硬碟的 AZ，就會發生衝突。
    *   **解決**：刪除 Pod 讓 Scheduler 重新嘗試，或確保節點橫跨多個 AZ。

### 🧪 數據一致性驗證 (Data Consistency Verification)
為了證明「數據真的有救回來」，我們可以在 Demo 流程中加入讀寫測試：

1.  **[災難前] 寫入機密數據**：
    ```powershell
    kubectl exec ebs-test-pod-a -- sh -c "echo '機密數據：2026總營收一千萬' > /data/secret.txt"
    ```
2.  **[復原後] 讀取並驗證**：
    ```powershell
    kubectl exec ebs-test-pod-a -- cat /data/secret.txt
    ```
    *   📢 **展示重點**：「大家可以看到，雖然 Pod 與 PVC 都被砍掉重練了，但我們寫入 `/data` 目錄的檔案依然完好如初。這證明了我們的備份機制成功保護了最關鍵的資料狀態。」

---

### 🔍 SRE 深度技術問答 (DR 核心原理)

#### Q1: Velero 的底層運作流程為何？
*   **控制平面 (Control Plane)**：Velero 是一個在 K8s 內運行的 Controller，它透過監聽 K8s API 來獲取資源清單。
*   **數據平面 (Data Plane)**：
    *   **YAML 物件**：由 Velero 壓縮後存入 S3。
    *   **磁碟數據 (EBS)**：Velero 透過 **AWS EBS CSI Plugin** 呼叫 AWS API 執行 `CreateSnapshot`。實體數據存放在 AWS 的快照倉庫中，S3 僅紀錄快照的 ID。

#### Q2: 為什麼目前的 S3 Bucket 是空的？
*   **模擬 vs 真實**：目前的演示是為了應對面試高壓環境的「高擬真模擬」。在真實環境中，安裝 Velero 需要配置 IAM Role 權限、S3 Bucket 權限與 CSI Driver 整合，備份過程通常需要 2-5 分鐘。
*   **面試話術**：「在 Demo 中我簡化了 S3 的讀寫等待，但在實際生產環境中，我們會配置 Velero 定時將 Snapshot ID 與資源清單同步至 S3，確保即便整個 K8s 叢集被誤刪，我們也能從外部 S3 重新拉回系統靈魂。」

#### Q3: 如何確保復原後的資料是一致的？
*   我們利用了 **EBS Snapshot 的區塊級備份 (Block-level Backup)**。這比檔案級備份更安全，因為它保證了磁碟在特定時間點的完整映像 (Image)。
*   這就是 **RPO (復原點目標)** 的核心：我們的 RPO 取決於備份的頻率（例如：每小時一次，則 RPO = 1hr）。

---

## 🧹 結束清理 (重要：防止 AWS 卡死與額外扣款)
> [!WARNING]
> 絕對不能直接跑 `terraform destroy`！
> 必須先用 `kubectl` 刪除 LoadBalancer、Ingress 與雲端硬碟，否則 AWS VPC 會因為有殘留的網卡 (ENI) 與安全群組 (Security Group) 而無法刪除（卡死報錯），且殘留的 EBS 硬碟會持續扣款！

1.  **清掃 K8s 產生的雲端資源 (NLB, ALB 與 EBS)**：
    ```powershell
    # 0. 【極度重要】砍掉所有透過 Argo CD 建立的 Application！
    # 否則 Argo CD 的 Self-Heal 機制會像殭屍一樣把您剛刪掉的 LoadBalancer/PVC 復活，導致 AWS 資源卡死！
    kubectl delete -f k8s/08-argo-application.yaml --ignore-not-found
    kubectl delete -f k8s/09-observability.yaml --ignore-not-found
    
    # 1. 刪除服務以釋放 AWS NLB (Network Load Balancer)
    kubectl delete -f k8s/03-service.yaml --ignore-not-found
    
    # 2. 刪除所有的 PVC 以釋放 AWS EBS 實體硬碟 (防止持續扣款)
    kubectl delete pvc --all --ignore-not-found
    
    # 【故障排除】如果 PVC 卡在 Terminating 刪不掉？
    # 通常是因為還有 Pod 正在掛載該硬碟。請執行：kubectl delete rollout --all
    ```

    > [!NOTE]
    > **🔍 技術原理解析：為什麼節點硬碟設定為 20 GiB？**
    > 「在 `eks.tf` 中，我為每個節點配置了 20 GiB 的 `gp3` 硬碟。這並非浪費，而是 EKS 的**最佳實踐最小規格**。Kubernetes 核心組件與我們安裝的治理工具 (Argo CD, Kyverno, Trivy) 的鏡像檔會佔用約 5-8 GiB。設定 20 GiB 能確保在長時間運作下，不會因為磁碟爆滿 (`DiskPressure`) 導致節點失效。在成本端，這僅增加極微小的支出，卻能換取 Demo 過程的絕對穩定。」

2.  **等待 1~2 分鐘**，確保 AWS 後台的 LoadBalancer 已經完全消失。
3.  **執行基礎設施銷毀**：
    ```powershell
    terraform destroy -auto-approve
    ```

    > [!NOTE]
    > **🔍 技術原理解析：為什麼要在 `terraform destroy` 前手動刪除 PVC 與 Service？ **
    > 這是 Terraform 與 Kubernetes 結合時常見的「雷點 (Gotcha)」。此為 Terraform 與 Kubernetes 整合時的常見陷阱，理解此機制能有效預防資源孤兒問題：
    > 「我刻意手動清除了 Service (NLB) 與 PVC (EBS)，是因為它們跨越了 K8s，向底層 AWS 索取了『叢集外』的實體資源。」
    > 「以 PVC 為例，如果直接執行 `terraform destroy`，Terraform 會粗暴地把 EKS 節點砍掉。這導致負責去 AWS 砍掉磁碟區的 **AWS EBS CSI Driver** 也跟著陣亡了，來不及執行清理。結果就是 Kubernetes 裡的資源雖然消失，但 AWS 後台的 EBS 磁碟區卻變成了『孤兒 (Orphaned Resources)』，持續計費且難以追蹤。」
    > 「因此，標準流程必須是在叢集還活著的時候，先讓 Kubernetes 控制器 (CSI Driver / AWS Load Balancer Controller) 有時間呼叫 AWS API 刪除實體資源。確認乾淨後，再交由 Terraform 執行基礎設施的銷毀。這展現了我對 IaC 邊界與 Kubernetes 動態資源生命週期的深刻理解。」

    > [!NOTE]
    > **🔍 技術原理解析：為什麼刪除 `.tf` 檔案後，`terraform destroy` 依然能順利執行？**
    > 「在剛才的實作中，我刪除了不再使用的資料庫設定檔 (`database.tf`)。很多人會擔心這會導致 `terraform destroy` 報錯，但實際上並不會。」
    > 「Terraform 依賴的是**狀態檔 (State File)** 而不是純粹的原始碼。由於資料庫已經建立並記錄在狀態檔中，`terraform destroy` 會直接讀取該狀態，依照當初建立的順序與清單，準確無誤地將雲端資源 (RDS/Redis) 徹底銷毀。這展現了 Terraform 作為狀態機 (State Machine) 的強大之處，也證明了我對基礎設施即代碼 (IaC) 核心運作機制的掌握程度。」

    > [!TIP]
    > **💡 專案維護小撇步：如何同步檔案刪除？**
    > 「在管理這個專案時，如果我手動刪除了某些本地檔案，我會透過 `git add .`、`git commit` 與 `git push` 的標準流程來確保 GitHub 遠端倉庫與本地保持同步。這體現了對版本控制系統 (VCS) 的嚴謹操作習慣，確保任何基礎設施的變動都有跡可循。」

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
> 無論您今天要展示場景一還是場景九，**底下的 0.1 到 0.3 步驟絕對不能跳過！**
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
> 1. **耐心等待掃描完成**：Trivy Operator 在剛安裝完後的 1-3 分鐘內可能還在啟動掃描任務，此時執行指令可能會看到 `No resources found`。若遇到此情況，請跟面試官解釋「掃描器正在進行初次全盤掃描」，稍等片刻即可。
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
**📂 涉及檔案**：`.github/workflows/security-scan.yml`, `.github/workflows/terraform-ci.yml`
**展示內容**：展示「左移資安 (Shift-Left)」，不用敲任何 K8s 指令，純展示瀏覽器畫面。

> [!TIP]
> **清潔與準備說明**：
> 本場景為純網頁展示，無須任何 K8s 前置安裝，展示完畢後亦**無須任何清潔動作**。
> 確認 GitHub Actions 頁面有 ✅ 綠色紀錄後即可開始展示。

---

### 🧠 情境背景說明

> **核心概念**：每當有人把程式碼推上 GitHub，GitHub 就會「自動幫你做品質檢查」，不需要人工干預。
>
> 
>
> 你的專案設定了兩條自動流水線：
> - **流水線 1 (`Security Scan`)** → 用 Trivy 工具自動掃描程式碼和 Image 有沒有已知安全漏洞，並吐出報告
> - **流水線 2 (`Terraform CI/CD`)** → 自動確認 Terraform 格式正確、沒有語法錯誤

---

### 👆 Step 1：打開 GitHub Actions 頁面

**操作**：打開瀏覽器 → 進你的 GitHub 專案 → 點上方 「Actions」 頁籤

**你會看到**：所有自動跑過的流水線列表

**說明**：
> 「你可以看到，這裡是 GitHub Actions 的流水線紀錄。每一次我 push 程式碼到 GitHub，這些流水線就會自動觸發，完全不需要人工干預。」

---

### 👆 Step 2：點進 Security Scan 那一筆

**操作**：點擊列表中的 「Security Scan」 那一行（有 ✅ 的那筆）

**你會看到**：左邊有 `Container Security Scan` 這個 Job

**操作**：點進去，點開 「Run Trivy vulnerability scanner in IaC mode」 那個步驟

**你會看到**：一大堆掃描輸出，像這樣：
```
CRITICAL: ... 
HIGH: ...
```

**說明**：
> 「這是 Trivy 工具在掃描我的 Terraform 基礎設施代碼，找出已知的安全漏洞（CVE）。你可以看到它產出了完整的漏洞清單。」
>
> 「在 Demo 環境裡我設定的是顯示報告但不中斷流程。但在真實生產環境，我會把它設成發現 HIGH/CRITICAL 漏洞就直接讓 Pipeline 失敗，阻止不安全的程式碼合併進主線。」

---

### 👆 Step 3：點進 Terraform CI/CD 那一筆

**操作**：返回 Actions 列表 → 點擊 「Terraform CI/CD (Multi-Tool Demo)」 那一行

**你會看到**：幾個步驟，包括 `Terraform Format Check`、`Run Checkov`、`Terraform Init`

**操作**：展開 「Run Checkov (Security Scan)」 步驟

**說明**：
> 「這條流水線用來確保我的基礎設施代碼品質。它會做三件事：第一，格式檢查，確保代碼風格一致；第二，用 Checkov 做靜態安全分析，抓出 Terraform 設定中的資安漏洞；第三，跑 Terraform Plan，預覽這次變更會對雲端資源造成什麼影響，讓工程師在合併前就能確認。」

---

### 🏆 Step 4：架構價值總結

**架構說明**：
> 「傳統的維運方式，往往是程式碼上線後才靠人工或事後掃描發現問題，修復成本非常高。我將 Trivy 與 Checkov 這些安全工具整合進 GitHub Actions，讓安全檢查在工程師提交 PR 的當下就自動執行。這就是所謂的『左移資安 (Shift-Left Security)』——把問題攔在最早、最便宜修復的階段。」

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
**展示內容**：展現您除了 K8s，也精通「作業系統 (OS)」層級的自動化配置。

> [!TIP]
> **清潔與準備說明**：
> 本場景主要展示腳本開發與架構觀念，沒有在 K8s 中產生新資源。展示完畢後**無須任何清潔動作**。

1.  **展示 Ansible 腳本與驗證**：
    *   **操作**：打開 VSCode 秀出 `ansible/node-hardening.yml`。
    *   **技術說明 (跨平台與除錯自動化)**：「因為這台工作站是 Windows 環境，預設無法直接執行 Linux 專用的 Ansible。但在現代雲端架構下，我們可以將維運工具『容器化』。透過此腳本，系統會自動在 EKS 中建立一個具備 Ansible 環境的臨時容器進行檢查。」
    *   **指令 (觸發容器化語法檢查)**：
        ```powershell
        .\bin\run-ansible.ps1 ansible/node-hardening.yml
        ```
    *   **🔍 結果解析 (這是給您看的防呆教學，也可以順著講給團隊聽)**：
        *   **這是在檢查什麼？** 這是「**語法檢查 (Syntax Check)**」。就像交卷前用軟體檢查有沒有拼字錯誤。它會檢查你的 YAML 縮排對不對、模組名稱有沒有拼錯，但**不會**真的去動到你的伺服器。
        *   **這份腳本實際上是做什麼用的？ (技術展示重點)** 如果我們真的把這份腳本套用到伺服器上，它會做這 5 件維運工程師最關心的事：
            1. **安裝系統更新**：自動把 Linux 的漏洞補丁打上。
            2. **安裝排障工具包**：預先裝好 `htop`、`tcpdump` 等網路查修工具，半夜機器出事時才不用花時間現裝。
            3. **統一系統時區**：強制設為 `Asia/Taipei`，確保未來查 Log 時時間對得上。
            4. **優化網路參數**：把作業系統的網路連線上限 (`somaxconn`) 調高，讓 K8s 節點能承受更大流量。
            5. **確保 SSM Agent 執行中**：確保我們能安全地遠端連線進機器排障。
           **畫面上的 `[WARNING]` 是報錯嗎？** 不是報錯，是**好消息**！這些警告只是在說：「你沒告訴我要連去哪台機器 (No inventory)」。這非常合理，因為我們只是在做「語法檢查」，本來就沒有要它真的連線去改機器。
        *   **哪裡看出來成功了？** 只要最後一行印出 `playbook: /playbook/node-hardening.yml`，且沒有出現紅色的 `ERROR` 
        字眼，就代表這份腳本語法 100% 正確，可以隨時投入生產環境使用。

2.  **解說 IaC 工具的職責邊界 (高階架構視野)**：
    *   📢 **向團隊總結 (大樓與房間的比喻)**：「很多工程師只會管 Kubernetes 裡面的 Pod，卻忘記了底層的 Linux 伺服器如果不安全，駭客一樣能攻破。我們可以把雲端架構想像成一棟大樓：
        1. **Terraform** 負責買地、蓋大樓本體 (AWS VPC、網路、實體節點)。
        2. **Ansible** (也就是我們剛剛檢查的腳本) 負責這棟大樓的**大門保全、水電與監視器**，它專門針對 **EKS 底層的工作節點 (EC2 實例的 Linux OS)** 進行安全補丁與系統優化。
        3. **Kubernetes** 負責管理大樓裡的房間，讓應用程式 (Pods) 安全地住進來。
    *   📢 **情境收尾**：「這三者結合，才是真正的雲原生基礎設施。透過這個展示，證明我不只懂容器，連最底層的 Linux 伺服器作業系統 (OS) 安全，都知道如何用 Ansible 進行自動化管理。」

## 🎭 場景九：可觀測性與監控 (Observability / Grafana)
**📂 涉及檔案**：`k8s/09-observability.yaml`
**展示內容**：展示透過 GitOps 一鍵部署企業級監控堆疊 (Kube-Prometheus-Stack)。

> [!IMPORTANT]
> **【關鍵等待：給 Argo CD 一點時間】**
> 當您執行完 `kubectl apply -f k8s/09-observability.yaml` 後，Argo CD 需要約 **30-60 秒** 才能下載完設定並建立 `monitoring` 命名空間。
> **如果您立刻執行步驟 1 的 port-forward 會報錯 `NotFound`。** 請先喝口水，等一分鐘後再繼續。
> 
> **檢查方法**：執行 `kubectl get ns` 看到 `monitoring` 出現後再開始。

> [!TIP]
> **前置準備**：
> 確保已透過 `kubectl apply -f k8s/09-observability.yaml` 部署設定，並等待 Argo CD 完成同步 (Sync)。由於包含多個 CRD 與元件，初次啟動約需 2-3 分鐘。

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

# 專案排障日誌 (Troubleshooting Log)

本文件紀錄了在基礎設施建置過程中遇到的技術挑戰、原因分析及最終解決方案。

---

## 🛑 問題一：RDS/Redis VPC 跨區域衝突 (VPC Mismatch)

### 1. 錯誤現象
執行 `terraform apply` 時報錯：
`InvalidParameterCombination: The DB instance and EC2 security group are in different VPCs.`

### 2. 原因分析 (Root Cause)
*   **動態環境重建**：當舊的 VPC 被刪除並建立新的 VPC 時，RDS 若沒有明確指定新的 `aws_db_subnet_group`，會預期性地去抓取帳號中的「預設 (Default)」子網群組。
*   **殘留關聯**：該預設群組可能仍關聯在舊的 VPC ID 上，導致新建立的安全群組（位於新 VPC）無法與之相容。

### 3. 解決方案
*   **代碼加固**：在 `vpc.tf` 中開啟 `create_database_subnet_group = true`，強制為每個新 VPC 建立專屬的子網群組。
*   **顯式相依性**：在 `database.tf` 中加入 `depends_on = [module.vpc]`，確保資料庫在網路環境完全就緒後才開始初始化。

---

## 🛑 問題二：Helm Chart 下載與快取失敗

### 1. 錯誤現象
`Error: could not download chart: no cached repo found.`

### 2. 原因分析 (Root Cause)
*   **環境依賴性**：Terraform 的 Helm Provider 在某些配置下會試圖讀取本地電腦的 `helm` 快取索引。
*   **命名不一致**：`k8sgpt` 的官方 Chart 名稱為 `k8sgpt-operator`，原配置中誤寫為 `k8sgpt`。

### 3. 解決方案
*   **去中心化配置**：在 `helm.tf` 中將所有 `repository` 改為完整的官方 URL，不再依賴本地 `helm repo add` 指令。
*   **名稱修正**：將 Chart 名稱修正為 `k8sgpt-operator`，確保與官方倉庫同步。

---

## 💡 經驗總結 (Lessons Learned)
*   **IaC 獨立性**：基礎設施代碼應儘可能減少對「執行者本地環境」的依賴（如本地 Helm Cache）。
---

## 🛑 問題三：ElastiCache (Redis) 子網群組遺失

### 1. 錯誤現象
`CacheSubnetGroupNotFoundFault: Cache Subnet Group ecommerce-eks-demo-vpc does not exist.`

### 2. 原因分析 (Root Cause)
*   **資源隔離性**：AWS 將 RDS 的子網群組與 ElastiCache 的子網群組視為完全獨立的資源。
*   **配置遺漏**：原本的 VPC 模組只啟用了資料庫子網群組，而 Redis 試圖引用該群組時發現類型不匹配或不存在。

### 3. 解決方案
*   **補全配置**：在 `vpc.tf` 中加入 `create_elasticache_subnet_group = true` 並定義專屬的 `elasticache_subnets`。
*   **引用修正**：將 `database.tf` 中的 `subnet_group_name` 改為引用 `module.vpc.elasticache_subnet_group_name`。

---

## 🛑 問題四：Helm Provider 持續嘗試讀取本地快取 (Persistent Cache Error)

### 1. 錯誤現象
`open C:\Users\kilok\AppData\Local\Temp\helm\repository\eks-index.yaml: The system cannot find the file specified.`

### 2. 解決方案 (Definitive Fix)
*   **強制本地快取 (Local Cache Path)**：在 `helm.tf` 的 `provider "helm"` 區塊中，加入 `repository_cache = "${path.module}/.helm_cache"`。
*   **原理**：這能強制 Terraform 將下載的 Chart 索引存放在專案目錄下的 `.helm_cache` 資料夾中，徹底避開 Windows 系統 Temp 資料夾權限或路徑不明導致的 `eks-index.yaml` 遺失報錯。
*   **執行動作**：
    ```powershell
    # 建立快取資料夾
    mkdir .helm_cache
    # 重新初始化並執行
    terraform init -upgrade
    terraform apply -auto-approve
    ```
### 3. 終極手段：手動建立「幽靈快取大禮包」 (Shotgun Ghost Files)
*   **情境**：Provider 會針對不同的 Helm Release 尋找不同的索引檔名（如 `eks-index.yaml`, `k8sgpt-index.yaml` 等）。
*   **解決方案**：一次性建立所有可能的幽靈檔案。
    ```powershell
    # PowerShell 一次性建立指令
    $files = @("eks-index.yaml", "k8sgpt-index.yaml", "argo-rollouts-index.yaml", "prometheus-index.yaml", "trivy-operator-index.yaml", "velero-index.yaml", "kyverno-index.yaml", "metrics-server-index.yaml", "argo-index.yaml")
    foreach ($f in $files) { echo "apiVersion: v1" > .helm_cache\$f }
    ```
*   **原理**：既然無法阻止 Provider 尋找本地快取，我們就提供符合最低 YAML 格式要求的偽造索引檔，強迫其跳過檢查並進入實際的下載流程。
---

## 🛑 問題五：大型組件部署超時 (Helm Timeout)

### 1. 錯誤現象
`Error: failed post-install: timed out waiting for the condition` (Prometheus, Kyverno)

### 2. 原因分析 (Root Cause)
*   **資源規模**：Prometheus Stack 包含數十個 CRD 與 Pod，在 EKS 剛啟動、節點還在擴縮時，預設的 10 分鐘不足以完成映像檔拉取與狀態就緒。
*   **網路延遲**：AWS 建立 EBS 磁碟並掛載至 Pod 的過程也需要時間，導致整體的 `Ready` 狀態延後。

### 3. 解決方案
*   **延長寬限期**：將 `helm_release` 的 `timeout` 設定延長至 1200 秒 (20 分鐘)。
*   **非同步部署**：針對 Prometheus 設定 `wait = false`，讓 Terraform 不需要死等所有 Pod Ready 即可繼續後續動作。

---

## 🛑 問題六：Velero Chart 版本 API 變更

### 1. 錯誤現象
`Invalid type. Expected: array, given: object` (針對 `configuration.backupStorageLocation`)

### 2. 原因分析 (Root Cause)
*   **Schema 演進**：最新版的 Velero Helm Chart 為了支援多個備份目標，將原本的單一物件格式改成了「物件陣列 (Array of Objects)」。

### 3. 解決方案
*   **語法修正**：將 Terraform 中的 `set` 參數從 `backupStorageLocation.name` 改為 `backupStorageLocation[0].name`，符合陣列索引格式。
---

## 🚀 最終架構優化：從 Helm Provider 轉向 Bootstrap Script

### 1. 決策背景
*   **環境侷限性**：在無 Helm CLI 的輕量級環境中，Terraform Helm Provider 的快取邏輯與 Windows Path 的相容性不穩定，導致部署時間長達 20 分鐘以上且易失敗。
*   **維運挑戰**：在面試或緊急災難復原 (DR) 場景，部署速度是關鍵指標。

### 2. 優化方案 (The Pivot)
*   **解耦 (Decoupling)**：將「雲端基礎設施 (Terraform)」與「平台中間件 (Kubectl Bootstrap)」解耦。
*   **優勢**：
    1.  **速度提升**：部署時間從 20+ 分鐘縮短至 3 分鐘以內。
    2.  **成功率提升**：改用官方原生 Manifests (YAML) 直接佈署，消除了中介層 (Helm Provider) 的出錯風險。
    3.  **靈活性**：符合現代「Cluster API」與「GitOps Bootstrapping」的思維，方便在不同叢集間快速移植。

### 3. 實作動作
*   簡化 `helm.tf` 僅保留 Provider 定義。
*   建立 `bootstrap-platform.ps1` 自動化安裝 Metrics Server, Argo Rollouts, Kyverno, Trivy Operator。
### 4. 技術對比分析 (Post-Mortem Analysis)

| 維度 | Terraform Helm Provider | Kubectl Bootstrap (Current) |
| :--- | :--- | :--- |
| **部署速度** | 20+ 分鐘 (含 State Refresh 與連線等待) | 3 分鐘 (直接 API 調用) |
| **參數靈活性** | 受限於 Provider 支援度 (如難以處理大型 CRD) | 極高 (可隨時加入 `--server-side` 等原生參數) |
| **穩定性** | 易受本地快取與 Windows 路徑限制影響 | 冪等性強，無本地相依性 |
| **維運思維** | 強耦合：基礎設施與應用綁定。 | 解耦：基礎設施 (Terraform) 與平台組件 (Bootstrap) 職責分離。 |

**架構結論：**
在平台工程實踐中，我們傾向於「基礎設施為先 (Infrastructure First)」。先用 Terraform 確保網路與運算資源的 100% 正確性，再透過 Bootstrap 程序注入平台能力。

**2026-05-09 更新實戰案例：**
在部署 Kyverno 時遇到 CRD 過大 (Too long) 導致 `kubectl apply` 失敗。透過 Bootstrap 腳本，我們能迅速切換為 `--server-side` 模式解決問題，展現了腳本在處理 K8s 原生特性時的靈活性與效率，這在純 IaC 工具中往往難以快速達成。

---

## 🛑 問題七：LoadBalancer 處於 Pending 且出現 403 Unauthorized

### 1. 錯誤現象
`Error syncing load balancer: failed to ensure load balancer: ... api error UnauthorizedOperation: You are not authorized to perform: ec2:DescribeInstances`

### 2. 原因分析 (Root Cause)
*   **權限遺失**：EKS 叢集的 IAM 角色缺少了管理網路資源的必要權限。
*   **影響範圍**：導致 K8s 無法調用 AWS API 來尋找對應的 EC2 節點並掛載至 LoadBalancer。

### 3. 解決方案
*   **強化 IAM 政策**：在 Terraform 中明確為 EKS Cluster Role 掛載 `AmazonEKSClusterPolicy` 與 `AmazonEKSVPCResourceController` 政策。
*   **驗證方式**：重新執行 `terraform apply` 後，觀察 `kubectl describe svc` 中的 Events 是否轉為 `EnsuringLoadBalancer` 成功狀態。

---

## 🛑 問題九：HPA 顯示 <unknown> 且副本數為 0

### 1. 錯誤現象
`kubectl get hpa` 顯示 `TARGETS: <unknown>/50%` 且 `REPLICAS: 0`。

### 2. 原因分析 (Root Cause)
*   **無效目標 (Target Miss)**：HPA 設定的對象（Deployment 或 Rollout）尚未被佈署，或副本數為 0。
*   **監控鏈路中斷**：Kubernetes 的 Metrics Server 無法從「不存在」的 Pod 中收集 CPU/Memory 數據。

### 3. 解決方案
*   **部署目標資源**：先執行 `kubectl apply -f k8s/02-rollout.yaml`。
*   **冷啟動等待**：確保 Pod 進入 `Running` 狀態後，給予 Metrics Server 約 60 秒的採集週期。
*   **驗證**：數據會從 `unknown` 自動轉變為具體的百分比（如 `2%/50%`）。

---

## 🛑 問題十：EKS 銷毀死結 (IGW/Subnet/VPC Deletion Deadlock)

### 1. 錯誤現象
執行 `terraform destroy` 時，進程長時間卡在 `module.vpc.aws_internet_gateway`、`module.vpc.aws_subnet.public` 或 `module.vpc.aws_vpc.this`（無限卡死），最終 AWS 報錯 `DependencyViolation: resource has dependent object`。

### 2. 原因分析 (Root Cause)
*   **權責分離 (Out-of-band Resources)**：由 Kubernetes Service (type: LoadBalancer) 自動生成的 NLB/ALB 負載平衡器，或 PVC 生成的 EBS 雲端硬碟，其生命週期是由 K8s 管理，而非 Terraform 狀態檔 (`.tfstate`)。
*   **網卡與安全群組殘留 (ENI & SG Blockade)**：若 EKS 叢集先於 K8s Service 被刪除，LB 會殘留在 AWS 帳號中。AWS 嚴格規定：
    1. 只要 Public Subnet 中還有掛載 Public IP 的網卡 (ENI) 存活，就不允許刪除 Subnet 與 IGW。
    2. 只要 VPC 內還有非預設的安全群組 (Security Group) 存活，就不允許刪除 VPC。
    這導致 Terraform 在嘗試摧毀網路架構時陷入無限死結。

### 3. 解決方案 (事後補救與事前預防)
*   **事後補救 (手動強制刪除)**：若已經發生卡死，須透過 AWS CLI 找出殘留的 LoadBalancer 與對應的 Security Group 並手動刪除。
    1.  強制刪除該 LoadBalancer (以 Classic LB 為例) 來釋放網卡：
        `aws elb delete-load-balancer --load-balancer-name <LB_NAME>`
    2.  找出並刪除殘留的 K8s 安全群組 (名稱通常帶有 `k8s-elb`) 來釋放 VPC：
        `aws ec2 delete-security-group --group-id <SG_ID>`
    3.  上述障礙物清除後，卡住的 `terraform destroy` 就會瞬間疏通並執行完畢。
*   **事前預防 (Demo 標準作業流程)**：
    強烈規範在執行 `terraform destroy` **之前**，必須先手動清掃 K8s 建立的雲端資源（由 K8s 正常刪除 Service 時，會自動幫你乾淨地清掉 LB、ENI 與 SG）：
    ```powershell
    kubectl delete -f k8s/03-service.yaml --ignore-not-found
    kubectl delete -f k8s/10-ingress.yaml --ignore-not-found
    kubectl delete pvc --all --ignore-not-found
    ```
    確認後台 LB 消失後，再執行基礎設施銷毀。這展現了平台工程師對 IaC 與 K8s 控制邊界的深刻理解。

---

## 🛑 問題十一：Pod 處於 Pending 狀態 (節點容量限制)

### 1. 錯誤現象
執行 `kubectl get pods` 時，發現 `ecommerce-backend` 或 `load-generator` 顯示為 `Pending`。
執行 `kubectl describe pod` 顯示：`0/2 nodes are available: 2 Too many pods.`

### 2. 原因分析 (Root Cause)
*   **硬體限制**：`t3.small` 實例在 EKS 預設網路配置下，每台機器上限僅能跑 11 個 Pod。
*   **資源過飽和**：當安裝了 Metrics Server, Argo Rollouts, Kyverno 等平台組件後，2 台節點的總量 (22) 已不足以支撐應用程式與壓測工具。

### 3. 解決方案
*   **水平擴充 (Scale Out)**：將 `eks.tf` 中的 `desired_size` 增加至 3，並放寬 `max_size` 至 5，確保有充足的 Pod Slots。
*   **架構思考**：在生產環境中，建議開啟 **「Prefix Delegation (前綴委派)」** 功能，這能讓 `t3.small` 支援高達 50+ 個 Pod，大幅提升資源利用率。

---

## 🛑 問題十二：金絲雀發布中的 EBS Multi-Attach 鎖死 (Deadlock)
  
### 1. 錯誤現象
在執行 `Argo Rollouts` 金絲雀發布時，新版本的 Pod 長時間卡在 `ContainerCreating` 狀態。
`kubectl describe pod` 顯示 `Multi-Attach error` 或 `Volume is already exclusively attached to one node`。
  
### 2. 原因分析 (Root Cause)
*   **儲存限制**：AWS EBS 屬於 **ReadWriteOnce (RWO)** 類型，同一時間只能掛載至一個 EC2 節點。
*   **發布策略衝突**：Argo Rollouts 在晉升 (Promote) 過程中，會先啟動新版本 Pod。如果新舊版本 Pod 被調度到不同節點，新 Pod 會因為舊 Pod 尚未釋放 EBS 鎖定而無法啟動。
*   **死結 (Deadlock)**：Argo Rollouts 預設會等待新 Pod Ready 才刪除舊 Pod，而新 Pod 卻在等待舊 Pod 刪除後釋放硬碟，造成循環等待。
  
### 3. 解決方案
*   **演示優化**：在測試/演示環境中，將副本數 (`replicas`) 降為 **1**，避免多副本間的掛載競爭。
*   **技術升級**：在生產環境中，建議改用 **Amazon EFS (Elastic File System)**，其支援 `ReadWriteMany` (RWX) 模式，可完美解決多 Pod 同時掛載與跨可用區存取問題。
*   **調度優化**：使用 **Node Affinity (節點親和性)** 確保新舊 Pod 始終運行在同一個 EC2 節點上，共享磁碟掛載點。
  
---
  
## 💡 經驗總結 (Lessons Learned)
*   **清理的徹底性**：`kubectl delete` 指令應配合 `-R` (Recursive) 參數，否則無法清理到 Kustomize `base/` 資料夾下的服務，這會導致 ELB 殘留。
*   **資源配額預估**：在規劃 EKS 叢集時，必須將「平台組件 (System Pods)」的數量納入計算，避免應用程式因排程限制而無法啟動。
*   **有狀態應用的挑戰**：Stateful 應用（使用 EBS）在進行漸進式交付時，必須考慮儲存卷的掛載能力限制，這往往是金絲雀發布中最容易被忽略的技術門檻。

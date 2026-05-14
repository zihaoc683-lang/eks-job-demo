## 結束清理（重要：防止 AWS 卡死與額外扣款）

> [!WARNING] **絕對不能直接跑 `terraform destroy`！** 必須先用 `kubectl` 刪除 LoadBalancer、Ingress 與雲端硬碟，否則 AWS VPC 會因為殘留的網卡（ENI）與安全群組（Security Group）而無法刪除，且殘留的 EBS 硬碟會持續扣款。若跳過此步驟，AWS 帳單可能產生孤兒資源費用且難以追蹤。

------

### Step 1｜清掃 K8s 產生的雲端資源

```powershell
# 0. [極度重要] 先停止 Argo CD Self-Heal
# 否則 Argo CD 會像殭屍一樣把剛刪掉的 LoadBalancer/PVC 復活，導致 AWS 資源卡死
kubectl delete -f k8s/08-argo-application.yaml --ignore-not-found
kubectl delete -f k8s/09-observability.yaml --ignore-not-found
# 09-observability.yaml 可能已由 Argo CD 自動部署，需確保清除

# 1. 清除場景十 DR Demo 專屬資源
.\bin\dr-demo.ps1 clean

# 2. 刪除所有 Rollout 與 Pod
kubectl delete rollout --all --ignore-not-found
kubectl delete pod --all --ignore-not-found

# 3. 刪除 Service 以釋放 AWS NLB（Network Load Balancer）
kubectl delete -f k8s/03-service.yaml --ignore-not-found
# 若場景二已清理，回傳 not found 為正常

# 4. 刪除所有 PVC 以釋放 AWS EBS 實體硬碟（防止持續扣款）
kubectl delete pvc --all --ignore-not-found

# 5. 確認 PVC 完全清除
kubectl get pvc
# 預期：No resources found in default namespace
```

> [!CAUTION] **PVC 卡在 Terminating 無法刪除？** 原因一：還有 Pod 正在掛載該硬碟 原因二：Argo CD Self-Heal 一直把 PVC 復活（最常見）
>
> 依序執行以下步驟：
>
> ```powershell
> # Step 1. 確認 Argo CD Application 已砍乾淨
> kubectl delete -f k8s/08-argo-application.yaml --ignore-not-found
> 
> # Step 2. 砍掉所有仍在掛載 PVC 的 Pod
> kubectl delete rollout --all --ignore-not-found
> kubectl delete pod --all --ignore-not-found
> 
> # Step 3. 強制移除 PVC Finalizer（Windows PowerShell 專用）
> $patch = '{"metadata":{"finalizers":[]}}'
> kubectl patch pvc ebs-claim --type=merge -p $patch
> 
> # Step 4. 確認清除完成
> kubectl get pvc
> # 預期：No resources found in default namespace
> ```

------

### Step 2｜確認 AWS LoadBalancer 已完全消失

```powershell
# 確認沒有帶 EXTERNAL-IP 的 Service 殘留
kubectl get svc -A
# 預期：只剩系統內建的 kubernetes service，無任何 EXTERNAL-IP
```

> **等待 1～2 分鐘**，確保 AWS 後台 LoadBalancer 已完全釋放，再繼續下一步。

------

### Step 3｜執行基礎設施銷毀

```powershell
terraform destroy -auto-approve
```

> **📢（為什麼要先手動刪除 PVC 與 Service）**：「我刻意手動清除了 Service（NLB）與 PVC（EBS），是因為它們跨越了 K8s，向底層 AWS 索取了叢集外的實體資源。如果直接執行 `terraform destroy`，Terraform 會直接把 EKS 節點砍掉，導致負責去 AWS 清理磁碟區的 EBS CSI Driver 也跟著陣亡，來不及執行清理。結果是 K8s 裡的資源消失，但 AWS 後台的 EBS 磁碟區變成孤兒（Orphaned Resources），持續計費且難以追蹤。標準流程是讓叢集還活著的時候，先讓 CSI Driver 有時間呼叫 AWS API 刪除實體資源，再交由 Terraform 銷毀基礎設施。」

> **📢（為什麼節點硬碟設定 20 GiB）**：「在 `eks.tf` 中我為每個節點配置了 20 GiB 的 `gp3` 硬碟。K8s 核心組件與治理工具（Argo CD、Kyverno、Trivy）的映像檔會佔用約 5～8 GiB，設定 20 GiB 確保長時間運作下不會因磁碟爆滿（`DiskPressure`）導致節點失效。在成本端僅增加極微小支出，卻換取 Demo 過程的絕對穩定。」

> **📢（為什麼刪除 `.tf` 檔案後 `terraform destroy` 依然能順利執行）**：「Terraform 依賴的是狀態檔（State File）而不是原始碼。`terraform destroy` 直接讀取狀態檔，依照當初建立的順序與清單，準確銷毀所有雲端資源。這展現了 Terraform 作為狀態機（State Machine）的強大之處，也證明了我對 IaC 核心運作機制的掌握。」

------

### Step 4｜最終確認

```powershell
# 確認所有資源已清除
kubectl get all -A
# 預期：只剩 kube-system 等系統內建資源

# 確認 terraform destroy 完成
terraform show
# 預期：The state file is empty. No resources are represented.
```

> [!TIP] **專案維護小撇步**：若有手動刪除本地檔案，透過標準 Git 流程同步遠端：
>
> ```powershell
> git add .
> git commit -m "chore: cleanup unused files"
> git push origin main
> ```
>
> 確保任何基礎設施變動都有跡可循。
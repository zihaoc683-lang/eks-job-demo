## 🎭 場景十：災難復原實戰 (Disaster Recovery / Velero)

**📂 涉及檔案**：`bin/dr-demo.ps1`, `demo-pods/ebs-pvc.yaml`, `demo-pods/ebs-test-pod-dr.yaml` **展示內容**：模擬應用層崩潰，展示 EBS Volume 獨立存活與資料完整復原。

> [!TIP] **演示意義 (SRE 講稿摘要)**：
>
> - **資料與計算分離**：Pod 死亡不等於資料死亡，EBS Volume 獨立於 Pod 生命週期存活
> - **RPO 趨近於零**：利用 AWS EBS Snapshot 機制，資料在災難發生前的狀態完整保留
> - **RTO 數分鐘內**：IaC + GitOps 化的配置讓復原流程全自動，MTTR 從數小時縮短至分鐘

------

### ⚠️ 演示前置作業

```powershell
# 停止 Argo CD Self-Heal，避免它搶占叢集資源
kubectl delete -f k8s/08-argo-application.yaml --ignore-not-found

# 清除場景二的 Canary 資源
kubectl delete rollout --all --ignore-not-found

# 清除場景十自身的舊資源
.\bin\dr-demo.ps1 clean

# 確認環境乾淨
.\bin\dr-demo.ps1 status
# 預期：Environment is CLEAN
```

------

### 🟢 第一階段：環境建置

**Step 1｜初始化環境**

```powershell
.\bin\dr-demo.ps1 init
# 腳本依序執行：
#   1. 建立 ebs-claim PVC（資料層）
#   2. 建立 ebs-test-pod-dr Pod（應用層）
#   3. 等待 Pod Ready
# 確認 PVC 已成功綁定
kubectl get pvc ebs-claim
# 預期：STATUS = Bound
```

**Step 2｜手動寫入機密資料**

```powershell
kubectl exec ebs-test-pod-dr -- sh -c "echo '機密資料：2026總營收一千萬' > /data/secret.txt"
# 確認資料已寫入
kubectl exec ebs-test-pod-dr -- cat /data/secret.txt
# 預期：機密資料：2026總營收一千萬
```

> **📢 旁白**：「我們已在 EBS 磁碟中手動寫入關鍵資料，這將作為等一下復原成功的唯一憑證。接下來模擬一場應用層崩潰。」

------

### 🔴 第二階段：災難發生

```powershell
.\bin\dr-demo.ps1 disaster
# 驗證 Pod 已消失，但 PVC 依然存在
kubectl get pod ebs-test-pod-dr --ignore-not-found
# 預期：No resources found

kubectl get pvc ebs-claim
# 預期：STATUS = Bound（PVC 完整保留）
```

> **📢 旁白**：「Pod 已經消失了——應用層徹底崩潰。但注意看，PVC 還在，STATUS 依然是 Bound。這說明 EBS Volume 的生命週期與 Pod 無關，它獨立存活於 AWS 基礎設施上。在真實的 Velero 架構中，即使連 PVC 也被刪除，我們仍可從 EBS Snapshot 重建。現在啟動復原程序。」

------

### 🟡 第三階段：一鍵復原

```powershell
.\bin\dr-demo.ps1 recover
# 腳本依序執行：
#   Step 1：基礎設施對齊（模擬 Terraform 確認雲端資源）
#   Step 2：確認資料層（PVC 仍 Bound，EBS Volume 完整）
#   Step 3：重建應用層（重新部署 Pod 並掛載原有 PVC）
```

> **📢 旁白**：「注意這次復原不需要重建 PVC——因為 EBS Volume 從未消失。腳本直接重建 Pod 並掛載原有的 EBS，這就是資料與計算分離架構的核心價值。」

------

### 🔵 第四階段：數據一致性驗證

```powershell
kubectl exec ebs-test-pod-dr -- cat /data/secret.txt
# 預期：機密資料：2026總營收一千萬
```

> **📢 旁白**：「大家看螢幕——資料原封不動地回來了。Pod 死了又活，但寫入 EBS 的資料完整保留。這體現了我們 RPO 趨近於零的高韌性架構，將 MTTR 從數小時縮短至不到一分鐘。」

------

### 🔍 技術原理說明

> **📢（RTO/RPO）**：「RPO 趨近於零：EBS Volume 在 Pod 崩潰期間完整保留，資料零遺失。RTO 僅需數分鐘：IaC 與 GitOps 化的設計讓所有配置都是代碼，復原等於重新執行代碼。」

> **📢（Velero 底層原理）**：「Velero 是在 K8s 內運行的 Controller。YAML 物件壓縮後存入 S3；EBS 磁碟資料透過 AWS EBS CSI Plugin 呼叫 `CreateSnapshot`，實體資料存放在 AWS 快照倉庫，S3 只記錄快照 ID。復原時 Velero 根據快照 ID 重建 EBS Volume 並重新綁定 PVC。」

> **📢（為什麼 S3 是空的）**：「Demo 中我簡化了 S3 的讀寫等待。真實生產環境會配置 Velero 定時將 Snapshot ID 與資源清單同步至 S3，確保即便整個叢集被誤刪，也能從外部 S3 重新拉回系統狀態。」

> **📢（為什麼場景十不直接使用 Velero）**：「細心的朋友可能會問——既然你們已經安裝了 Velero，為什麼這個場景不直接跑一次完整的 `velero backup create` 和 `velero restore create`？
>
> 原因有三個。第一是**時間成本**：Velero 的完整 Backup 流程包含呼叫 EBS CreateSnapshot，AWS 建立快照通常需要 3 到 10 分鐘，加上 Restore 重建 Volume 再掛載 PVC，端到端等待時間容易超過 15 分鐘，不適合 Demo 現場。
>
> 第二是**觀念優先於工具**：這個場景的核心論點是『資料與計算分離』——EBS Volume 的生命週期獨立於 Pod。這個概念在不依賴 Velero 的情況下反而更直觀：觀眾能清楚看到 Pod 死亡、PVC 存活、資料完整，論點更乾淨。
>
> 第三是**Velero 解決的是更極端的場景**：當 PVC 本身也被刪除、或整個叢集被誤刪時，才真正需要 Velero 從 S3 的快照 ID 重建一切。場景十示範的是日常應用層崩潰的 RTO，Velero 則是應對叢集級災難的最後一道防線。兩者是不同層次的保護機制，互補而非重複。」

------

### 🔍 SRE 實戰排障指南

**Pod 卡在 Pending 時**，執行 `kubectl describe pod ebs-test-pod-dr` 確認原因：

| 現象                            | 原因                                     | 對策                                             |
| ------------------------------- | ---------------------------------------- | ------------------------------------------------ |
| `Too many pods`                 | EKS 小型節點 Pod 數量上限（受限 ENI IP） | 清除不必要的 Demo 資源，展示叢集容量管理能力     |
| `ebs-claim not found`           | PVC 被誤刪                               | 執行 `.\bin\dr-demo.ps1 clean` 後重新 `init`     |
| `Volume Node Affinity Conflict` | EBS 建在 AZ-A，Pod 調度到 AZ-B           | 刪除 Pod 讓 Scheduler 重新嘗試                   |
| Argo CD Self-Heal 搶資源        | Argo CD 偵測到狀態不一致自動復原其他應用 | `kubectl delete -f k8s/08-argo-application.yaml` |

------

### ⚪ 收尾清理

```powershell
.\bin\dr-demo.ps1 clean

# 確認清除乾淨
.\bin\dr-demo.ps1 status
# 預期：Environment is CLEAN
```

> **📢 結語**：「這套流程證明了我們具備應對應用層災難的能力，將 MTTR 從數小時縮短至不到一分鐘。」

> **⚠️ 特別注意（跨場景資源保留）**：
>
> | 資源                            | 本場景結束後          | 原因                                                |
> | ------------------------------- | --------------------- | --------------------------------------------------- |
> | `pvc ebs-claim`                 | ❌ **已由 clean 刪除** | 場景十是最後一個場景，無需保留                      |
> | `ebs-test-pod-dr`               | ❌ **已由 clean 刪除** | 場景十專屬 Pod                                      |
> | Kyverno / Trivy / Argo Rollouts | ✅ **保留**            | Bootstrap 安裝，需手動 `terraform destroy` 才會移除 |
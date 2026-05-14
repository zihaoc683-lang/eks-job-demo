## 🎭 場景四：雲端存儲持久化 (EBS Storage)

**📂 涉及檔案**：`demo-pods/ebs-pvc.yaml`, `demo-pods/ebs-test-pod-a.yaml`, `demo-pods/ebs-test-pod-b.yaml` **展示內容**：證明 K8s Pod 壞掉後，資料「不會不見」。

> [!TIP] **演示意義 (SRE 講稿摘要)**：
>
> - **數據與計算分離**：Pod 是短暫的，EBS 是持久的。Pod 死掉不等於資料死掉
> - **雲原生存儲**：透過 AWS EBS CSI Driver，K8s 自動管理雲端硬碟的建立與掛載
> - **AZ 感知調度**：`WaitForFirstConsumer` 確保硬碟與 Pod 永遠在同一個可用區

------

### ⚠️ 演示前置作業（環境大掃除）

```powershell
# 清除前一場景殘留 + 確保沒有舊的 ebs-test-pod 活著
# [關鍵] ReadWriteOnce 的 EBS 同時只能被一個 Pod 掛載
# 若舊 Pod 還活著佔用 EBS，新 Pod 會永遠卡在 Pending
kubectl delete pod bad-pod-security-violation test-nginx ebs-test-pod-a ebs-test-pod-b --ignore-not-found

# 確認所有 Pod 已清除
kubectl get pods
# 預期：No resources found in default namespace
# 確認 PVC 狀態
kubectl get pvc ebs-claim
```

> **PVC 狀態對照表**：
>
> | 狀態      | 意義                                                         | 處置                                      |
> | --------- | ------------------------------------------------------------ | ----------------------------------------- |
> | `Pending` | 正常起始狀態，等待 Pod 觸發 EBS 建立（`WaitForFirstConsumer`） | 直接繼續                                  |
> | `Bound`   | EBS 已建立，前次演示留下                                     | 確認無舊 Pod 佔用，直接繼續               |
> | 不存在    | PVC 被誤刪                                                   | `kubectl apply -f demo-pods/ebs-pvc.yaml` |

------

### Step 1｜部署 Pod A 並寫入資料

```powershell
kubectl apply -f demo-pods/ebs-test-pod-a.yaml
```

> **📢 旁白**：「Pod A 啟動時會自動執行一行指令，把『總營收一千萬』寫入 EBS 上的 `/data/secret.txt`。這模擬企業核心資料寫入持久化存儲的情境。」

```powershell
# 等待 Pod A Ready（EBS 首次建立需要約 30~60 秒）
# 此時 PVC 狀態會從 Pending 變為 Bound
kubectl wait --for=condition=Ready pod/ebs-test-pod-a --timeout=90s

# 確認 PVC 已成功綁定
kubectl get pvc ebs-claim
# 預期：STATUS = Bound
# 驗證資料已寫入 EBS
kubectl exec ebs-test-pod-a -- cat /data/secret.txt
# 預期輸出：總營收一千萬
```

------

### Step 2｜強行殺掉 Pod A ⚡

```powershell
kubectl delete pod ebs-test-pod-a
```

> **📢 旁白（刪除後立即說）**：「Pod A 已經消失了。在傳統架構中，這代表資料也跟著不見。但在 K8s + EBS 的架構下，硬碟是獨立存在於 AWS 的，Pod 的生死不影響資料。現在我們用一個全新的 Pod B 來掛載同一顆 EBS，看看資料還在不在。」

```powershell
# 確認 Pod A 完全終止，EBS 已釋放，再繼續下一步
# [關鍵] ReadWriteOnce 要求前一個 Pod 完全釋放後，下一個才能掛載
kubectl get pod ebs-test-pod-a
# 預期：Error from server (NotFound)
```

------

### Step 3｜部署 Pod B 驗證資料存活 ⚡

```powershell
kubectl apply -f demo-pods/ebs-test-pod-b.yaml
# 等待 Pod B Ready（重新掛載既有 EBS，通常比首次建立快）
kubectl wait --for=condition=Ready pod/ebs-test-pod-b --timeout=90s
# 驗證資料依舊存在
kubectl exec ebs-test-pod-b -- cat /data/secret.txt
# 預期輸出：總營收一千萬
```

> **📢 旁白（驗證成功後說）**：「資料還在。Pod A 死掉了，但 EBS 上的資料完好無缺，Pod B 掛載同一顆硬碟就能直接讀到。這就是數據與計算分離的核心價值。」

------

### Step 4｜技術原理說明

> **📢（跨可用區感知）**：「我的 StorageClass 設定了 `WaitForFirstConsumer`。EBS 是綁定特定可用區的，如果設成立即建立，硬碟可能建在 AZ-A，但 Pod 卻被調度到 AZ-B，導致永遠無法掛載。這個設定讓 K8s 調度器先決定 Pod 落在哪個 Node，再通知 AWS 在同一個 AZ 建立硬碟，這是多可用區高可用架構的必備設定。」

> **📢（存儲選型）**：「這次演示選用 EBS，特性是 `ReadWriteOnce`，同時只能被一個 Pod 掛載，適合資料庫這類需要獨佔高效能 IOPS 的應用。如果真實場景需要多個 Pod 同時讀寫同一份檔案（例如共用圖片庫），就要改用 AWS EFS 搭配 `ReadWriteMany`。根據業務需求選擇正確的存儲底層，是 SRE 的核心能力之一。」

------

### 🧹 收尾清理

```powershell
# 刪除 Pod B，釋放 EBS 掛載
kubectl delete pod ebs-test-pod-b --ignore-not-found

# 確認環境乾淨
kubectl get pods
# 預期：No resources found in default namespace
```

> **⚠️ 特別注意（跨場景資源保留）**：
>
> | 資源                                | 本場景結束後 | 原因                                  |
> | ----------------------------------- | ------------ | ------------------------------------- |
> | `pvc ebs-claim`                     | ✅ **保留**   | 場景十（災難復原）依賴                |
> | Kyverno / Argo Rollouts / Trivy     | ✅ **保留**   | Bootstrap 安裝，後續場景依賴          |
> | `demo-pods/ebs-pvc.yaml` 建立的 PVC | ✅ **保留**   | 勿執行 `kubectl delete pvc ebs-claim` |
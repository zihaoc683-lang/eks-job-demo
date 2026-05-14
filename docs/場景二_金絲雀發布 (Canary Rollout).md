## 🎭 場景二：金絲雀發布 (Canary Rollout) - P0 核心

**📂 涉及檔案**：`k8s/02-rollout.yaml`, `k8s/03-service.yaml` **展示內容**：模擬「錯誤版本上線 → 秒級回滾 → 正確版本上線 → 漸進式放量」。

------

### ⚠️ 演示前置作業（環境大掃除）

```powershell
# 確保 Revision 從 #1 開始，並避免 HPA 干擾副本數
# （HPA 會自動調整副本數，干擾我們對 Canary weight 的觀察）
kubectl delete rollout ecommerce-backend --ignore-not-found
kubectl delete svc ecommerce-svc --ignore-not-found
kubectl delete hpa ecommerce-hpa --ignore-not-found

# 重新建立 Rollout 與 Service
kubectl apply -f k8s/02-rollout.yaml
kubectl apply -f k8s/03-service.yaml

# 等待 EXTERNAL-IP 就緒
kubectl get svc ecommerce-svc -w
```

------

### Step 1｜檢查初始狀態

```powershell
.\bin\kubectl-argo-rollouts.exe get rollout ecommerce-backend -w
```

> **意義**：確認目前只有 **Revision 1**，Strategy 為 Canary，Status 為 `Healthy`，所有副本均為 `Running`。這是金絲雀演示的起始基準線。

------

### 階段 A｜模擬「故障」版本上線 ⚡

```powershell
.\bin\kubectl-argo-rollouts.exe set image ecommerce-backend backend=stefanprodan/podinfo:9.9.9-error

# 觀察 Canary Pod 狀態
.\bin\kubectl-argo-rollouts.exe get rollout ecommerce-backend -w
```

> **📢 架構介紹**：「現在模擬工程師不小心推送了一個不存在的映像檔標籤。從畫面可以看到：
>
> - **Revision 2**（canary）的 Pod 狀態是 `⚠️ ErrImagePull`，`ready:0/1`
> - **Revision 1**（stable）的 Pod 依然 `✅ Running`，`ready:1/1`
> - Rollout 整體狀態是 `Progressing`，但 `ActualWeight: 0`，代表**錯誤版本尚未承接任何真實流量**
>
> 這就是控制『爆炸半徑 (Blast Radius)』的核心價值：在傳統 Deployment 中這會導致服務滾動更新失敗甚至中斷，但在 Canary 模式下，穩定版本始終保護著剩餘用戶。」

------

### 階段 B｜秒級回滾 (Rollback) ⚡

```powershell
.\bin\kubectl-argo-rollouts.exe undo ecommerce-backend

# 確認系統已完全回到穩定版本
.\bin\kubectl-argo-rollouts.exe get rollout ecommerce-backend -w
```

> **預期現象**：Revision 2 的 ReplicaSet 縮為 `ScaledDown`，Revision 1 重新成為唯一的 `stable`，Status 回到 `Healthy`。確認回穩後再進行下一階段。
>
> **📢 架構介紹**：「發現錯誤後，不需要手動修改 YAML，一個 `undo` 指令就能實現秒級回滾，將爆炸半徑降到最低。這是 Argo Rollouts 相比原生 Deployment 最關鍵的生產價值。」

------

### 階段 C｜正確版本上線 (v6.3.0) ⚡

```powershell
.\bin\kubectl-argo-rollouts.exe set image ecommerce-backend backend=stefanprodan/podinfo:6.3.0

# 觀察流量停在 20%（Step 1/5，CanaryPauseStep）
.\bin\kubectl-argo-rollouts.exe get rollout ecommerce-backend -w
```

> **預期畫面**（對應截圖四）：
>
> ```
> Status:   ‖ Paused
> Message:  CanaryPauseStep
> Step:     1/5
> SetWeight:   20
> ActualWeight: 50        ← 因單副本取整，實際流量略高於設定值
> Images:
>   stefanprodan/podinfo:6.2.3 (stable)
>   stefanprodan/podinfo:6.3.0 (canary)
> Replicas:
>   Current: 2            ← stable + canary 各一個 Pod 同時運行
>   Ready:   2
> ```
>
> **📢 架構介紹**：「修正版本上線後，系統進入 Canary 觀察期，流量停在 SetWeight 20%。這裡有個值得注意的細節：`ActualWeight` 顯示 50 而非 20，原因是我們只有 1 個 desired replica，Kubernetes 最小粒度是 1 個 Pod，所以實際流量比例會因取整而偏高。生產環境副本數越多，這個誤差越小。
>
> `pause: {}` 是我在 YAML 中設定的人工關卡，系統會停在這裡等待人工確認，確保有足夠時間觀察指標後再決定是否晉升。」

------

### 階段 D｜全量推動 (Promote) ⚡

```powershell
.\bin\kubectl-argo-rollouts.exe promote ecommerce-backend

# 觀察晉升過程
.\bin\kubectl-argo-rollouts.exe get rollout ecommerce-backend -w
```

> **預期畫面**（對應截圖二 → 截圖一）：
>
> ```
> # promote 執行中（截圖二）
> Status:      ‖ Paused
> SetWeight:   20
> ActualWeight: 50
> → canary Pod Running，stable Pod Running
> 
> # 晉升完成（截圖一）
> Status:    ✅ Healthy
> Step:      5/5
> SetWeight: 100
> ActualWeight: 100
> Images:    stefanprodan/podinfo:6.3.0 (stable)   ← canary 晉升為新的 stable
> Replicas:  Desired/Current/Updated/Ready/Available: 1
> ```
>
> **📢 架構介紹**：「確認無誤後執行 `promote`，流量依序經過各 Step 直至 100%。最終所有 Pod 均更新為 v6.3.0，舊的 ReplicaSet 縮為 `ScaledDown` 保留備用，隨時可以再次 `undo`。整個過程零停機、可觀測、可回滾。」

------

### 🧹 收尾清理

```powershell
# 刪除 Canary 部署資源
kubectl delete rollout ecommerce-backend --ignore-not-found
kubectl delete svc ecommerce-svc --ignore-not-found

# 確認清除乾淨
kubectl get pods
kubectl get svc
```

> **預期結果**：
>
> - `kubectl get pods` → `No resources found in default namespace`
> - `kubectl get svc` → **只剩系統內建的 `kubernetes`**，ecommerce-svc 已消失

> **⚠️ 特別注意（跨場景資源保留）**：
>
> | 資源                            | 本場景結束後 | 原因                         |
> | ------------------------------- | ------------ | ---------------------------- |
> | `pvc ebs-claim`                 | ✅ **保留**   | 場景四、場景十依賴           |
> | Kyverno / Trivy / Argo Rollouts | ✅ **保留**   | Bootstrap 安裝，後續場景依賴 |
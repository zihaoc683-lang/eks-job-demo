## 🎭 場景七：GitOps 持續交付 (Argo CD) — 破壞性修復展示

**📂 涉及檔案**：`k8s/08-argo-application.yaml`, `k8s/base/`, `k8s/overlays/production/` **展示內容**：GitOps 最高境界——「配置偏移自動修復 (Drift Detection)」與 Kustomize 架構。

> [!TIP] **演示意義 (SRE 講稿摘要)**：
>
> - **單一真相來源**：Git 倉庫是環境的唯一真相，任何人為改動都會被自動撤銷
> - **Drift Detection**：Argo CD 持續比對 Git 與叢集狀態，發現偏移立即修復
> - **Kustomize 分層架構**：base 定義共通設定，overlays 針對環境客製化，消除多份 YAML 的維護困境

------

### ⚠️ 演示前置作業

> [!IMPORTANT] **推送程式碼（必做）**：Argo CD 從 GitHub 遠端倉庫拉取設定，不讀取本地檔案。確保所有修改已 push 上 GitHub，否則 Argo CD 無法取得最新設定。
>
> ```powershell
> git add .
> git commit -m "chore: prepare argocd demo"
> git push origin main
> ```

```powershell
# 清除舊有資源（重複演練時執行）
# [關鍵] 必須先刪 Application，阻止 Self-Heal 在清掃過程中復活資源
kubectl delete application ecommerce-app -n argocd --ignore-not-found

# 確認 Application 已完全刪除再繼續
kubectl get application -n argocd
# 預期：No resources found

# 再刪工作負載
kubectl delete rollout ecommerce-backend --ignore-not-found
kubectl delete svc ecommerce-svc --ignore-not-found

# 確認清除乾淨
kubectl get rollout,svc
# 預期：No resources found
```

------

### Step 0｜確認 Argo CD 狀態

> **Argo CD 已由 `bootstrap-platform.ps1` 預裝，正常情況下無需重新安裝。** 本步驟只需確認 Pod 就緒即可繼續。

```powershell
# 確認 argocd namespace 存在
kubectl get namespace argocd
# 預期：STATUS = Active
```

> [!CAUTION] **若回傳 `not found`**：Bootstrap 未完整執行，執行補救指令：
>
> ```powershell
> kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
> kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
> kubectl -n argocd wait --for=condition=ready pod --all --timeout=120s
> ```

```powershell
# Bootstrap 安裝後不會等待 Pod 就緒，此處必須手動確認
# 若 Pod 尚未 Ready 就 apply Application，controller 無法處理同步任務
kubectl -n argocd wait --for=condition=ready pod --all --timeout=120s

# 確認所有 Pod 狀態
kubectl get pods -n argocd
# 預期：argocd-server、argocd-repo-server、argocd-application-controller 均為 Running
```

------

### Step 1｜套用 Application

```powershell
kubectl apply -f k8s/08-argo-application.yaml
# 確認 Application 已被 Argo CD 接收並開始同步
kubectl get application ecommerce-app -n argocd
# 預期：SYNC STATUS = Synced，HEALTH STATUS = Healthy
# 若顯示 Progressing，等待約 30 秒後再次確認
```

------

### Step 2｜設定固定密碼

```powershell
# 前提：確認 Python 與 bcrypt 套件已安裝
pip install bcrypt

# 產生密碼 hash
$hash = python -c "import bcrypt; print(bcrypt.hashpw(b'ArgoDemo2026!', bcrypt.gensalt(rounds=10)).decode())"

# 寫成 patch 檔
@"
{"stringData": {"admin.password": "$hash", "admin.passwordMtime": "2024-01-01T00:00:00Z"}}
"@ | Out-File -FilePath patch.json -Encoding utf8

# 寫入 secret
kubectl -n argocd patch secret argocd-secret --patch-file patch.json
```

> **💡 說明**：每次執行產生的 hash 字串不同，但都對應同一密碼 `ArgoDemo2026!`，這是 bcrypt 加鹽機制的正常行為。

------

### Step 3｜重啟 argocd-server 讓密碼生效

```powershell
kubectl -n argocd rollout restart deployment argocd-server

# 等待重啟完成
kubectl -n argocd rollout status deployment argocd-server
# 看到 successfully rolled out 再繼續
```

------

### Step 4｜開啟 Port Forward

> **⚠️ 此指令會佔用目前終端機。請先另開一個終端機視窗，後續的破壞指令在新視窗執行。**

```powershell
# 使用 9091 避免 Windows 常見的 Port 佔用問題（8080/9090 易衝突）
kubectl port-forward svc/argocd-server -n argocd 9091:443
```

------

### Step 5｜登入 Argo CD 介面

- **URL**：`https://localhost:9091`
- **帳號**：`admin`
- **密碼**：`ArgoDemo2026!`

瀏覽器忽略憑證警告後登入，確認 `ecommerce-app` 顯示綠色 `Healthy` 與 `Synced`。

> **📢 旁白（登入後說）**：「這是 Argo CD 的控制台。畫面上的 `ecommerce-app` 是我在 `08-argo-application.yaml` 定義的監控任務。它正在追蹤 GitHub 上 `k8s/overlays/production` 目錄的最新狀態，並確保叢集與 Git 保持一致。」

> **📢 旁白（介紹 Kustomize 時說）**：「點進去可以看到這個 App 部署了哪些資源。這些資源來自 Kustomize 的 base + production overlay 合併結果。傳統部署中，Dev 和 Prod 環境往往各自維護一份 YAML，改一個設定要改兩個地方。Kustomize 讓共通設定集中在 base，production 只需要寫差異的部分，確保基礎架構的唯一真相。」

------

### 💪 破壞展示｜Drift Detection ⚡

> **📢 旁白（破壞前說）**：「現在模擬一個常見的維運事故：有工程師直接用 kubectl 刪除了線上的 Service，但沒有改 Git。在傳統架構中，這個 Service 就消失了，直到有人發現並手動修復。在 GitOps 架構下，看看會發生什麼事。」

**在新的終端機視窗執行破壞指令**：

```powershell
kubectl delete svc ecommerce-svc
```

**同時在 CLI 觀察自動修復過程**：

```powershell
# 持續監控 Service 狀態
kubectl get svc ecommerce-svc -w
# 預期：Service 消失後數秒內自動重建
```

**同時切換回 Argo CD UI 觀察**：

狀態瞬間變成黃色 `Out of Sync` → 數秒內自動重建 Service → 恢復綠色 `Healthy`

> **📢 旁白（修復完成後說）**：「看到了嗎？Service 被刪除後，Argo CD 發現叢集狀態與 Git 不一致——這就是 Configuration Drift。因為設定了 `selfHeal: true`，它毫不猶豫地把 Service 重建回來。整個過程不需要人工介入，這就是 GitOps 的自我修復能力。」

------

### 🔍 技術原理說明（修復完成後說）

> **📢（單一真相來源）**：「GitOps 的核心精神是：Git 倉庫裡的程式碼就是環境的唯一真相。Argo CD 是這個真相的守護者，任何人直接 `kubectl edit` 或 `kubectl delete` 的改動，都會在下一個對帳週期被撤銷。」

> **📢（調和迴圈）**：「Argo CD 內部有一個 Controller，每 3 分鐘（預設值）比對 Git 上的 YAML 與 K8s 實際運行的資源，如同會計在定期對帳。也可以設定 Webhook 讓 GitHub push 時即時觸發，不需等待 3 分鐘。」

> **📢（自我修復）**：「`selfHeal: true` 讓 Argo CD 在發現 Drift 時自動 apply Git 上的設定。`prune: true` 讓 Git 上刪除的資源在叢集裡也被清除。兩者搭配，確保叢集狀態永遠與 Git 一致，徹底杜絕『手動改線上機器卻不改 Code』的壞習慣。」

------

### 🧹 收尾清理

**Step 1｜停止 Port Forward**

在執行 port-forward 的終端機按 `Ctrl + C`。若找不到該視窗：

```powershell
$portPid = Get-NetTCPConnection -LocalPort 9091 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess
if ($portPid) { Stop-Process -Id $portPid -Force -ErrorAction SilentlyContinue }
echo "Port 9091 已釋放"
```

**Step 2｜先刪 Application，阻止 Self-Heal 復活資源**

```powershell
kubectl delete -f k8s/08-argo-application.yaml --ignore-not-found

# 確認 Application 已完全刪除，Self-Heal 已停止，再繼續
kubectl get application -n argocd
# 預期：No resources found
```

**Step 3｜刪除場景工作負載**

```powershell
kubectl delete rollout ecommerce-backend --ignore-not-found
kubectl delete svc ecommerce-svc --ignore-not-found
```

**Step 4｜刪除 Argo CD 本體**

```powershell
kubectl delete namespace argocd
```

**Step 5｜刪除暫存檔**

```powershell
Remove-Item -Path patch.json -ErrorAction SilentlyContinue
```

**Step 6｜確認清除乾淨**

```powershell
kubectl get namespace
kubectl get pods -A
# 預期：argocd namespace 不存在
```

> **⚠️ 特別注意（跨場景資源保留）**：
>
> | 資源                            | 本場景結束後 | 原因                                |
> | ------------------------------- | ------------ | ----------------------------------- |
> | `pvc ebs-claim`                 | ✅ **保留**   | 場景十依賴                          |
> | Kyverno / Trivy / Argo Rollouts | ✅ **保留**   | Bootstrap 安裝，後續場景依賴        |
> | `argocd` namespace              | ❌ **刪除**   | 場景七專屬，後續場景不依賴          |
> | `patch.json`                    | ❌ **刪除**   | 暫存檔含密碼 hash，清除避免安全疑慮 |
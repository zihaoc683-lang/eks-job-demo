## 🎭 場景三：政策治理 (Governance / Kyverno) - P0 核心

**📂 涉及檔案**：`k8s/07-kyverno-policy.yaml`, `k8s/03-bad-pod.yaml` **展示內容**：防止工程師「誤操作」導致的安全漏洞，示範 API 層主動攔截的威力。

> [!TIP] **演示意義 (SRE 講稿摘要)**：
>
> - **主動防護**：與其事後修補，在 API 入口 (Admission Control) 直接攔截風險
> - **供應鏈安全**：強制限定映像檔來源，杜絕從不明倉庫抓取惡意程式
> - **治理自動化**：將安全手冊化為程式碼，實現 24/7 自動化監管，這就是 **Policy as Code** 的實踐

------

### ⚠️ 演示前置作業（環境大掃除）

```powershell
# 移除舊 Policy（讓「安裝政策」步驟更有戲劇感）
kubectl delete clusterpolicy disallow-privileged-containers --ignore-not-found

# [關鍵] 必須先刪除所有測試 Pod
# Kyverno 只攔截「新建立」的資源，若 Pod 已存在則 apply 回傳 unchanged
# 不會觸發 Admission Webhook，導致演示失效
kubectl delete pod test-nginx bad-pod-security-violation --ignore-not-found

# 確認環境已完全清除
kubectl get pods
# 預期：No resources found in default namespace
```

------

### Step 0｜Before — 無政策時，壞 Pod 可以正常建立

```powershell
# 尚未安裝任何 Policy，直接建立違規 Pod
kubectl apply -f k8s/03-bad-pod.yaml

# 確認 Pod 成功建立
kubectl get pods
# 預期：bad-pod-security-violation   Running
```

> **📢 旁白**：「現在叢集沒有任何防護政策。這個 Pod 使用了 `privileged: true`，等同讓容器取得宿主機 root 權限，攻擊者可以藉此逃逸並控制整台 Node。但現在它毫無阻礙地跑起來了。接下來我們裝上 Kyverno Policy，看看差別。」

```powershell
# 清除剛才建立的壞 Pod，準備進入 After 階段
kubectl delete pod bad-pod-security-violation --ignore-not-found
```

------

### Step 1｜安裝安全政策

```powershell
kubectl apply -f k8s/07-kyverno-policy.yaml
```

> **⚠️ 注意**：這建立的是 `ClusterPolicy`（法條），**不是 Pod**，不會有容器跑起來。

```powershell
# 必須等 READY = True 才能繼續，否則 Webhook 尚未就緒會漏放請求
kubectl wait --for=condition=Ready clusterpolicy/disallow-privileged-containers --timeout=30s

# 確認政策狀態
kubectl get clusterpolicy disallow-privileged-containers
# 預期：READY = True、ADMISSION = true
```

> **📢 旁白**：「Policy 已生效。這份 YAML 包含兩條規則：第一條禁止 `privileged: true`，同時掃描主容器與 initContainers，避免攻擊者把特權設定藏在初始化容器裡繞過檢查。第二條限制映像檔只能來自 `ghcr.io`、`stefanprodan` 或 `alpine`，其他來源一律拒絕。」

------

### Step 2｜After — 攔截特權容器 ⚡

```powershell
kubectl apply -f k8s/03-bad-pod.yaml
```

> **預期報錯**：
>
> ```
> Error from server: error when creating "k8s/03-bad-pod.yaml":
> admission webhook "validate.kyverno.svc-fail" denied the request:
> policy Pod/default/bad-pod-security-violation for resource violation:
> disallow-privileged-containers/validate-privileged:
> 不允許建立特權容器！這違反了公司的安全基準政策。
> ```

```powershell
# 即時確認 Pod 完全沒有被建立
kubectl get pods
# 預期：No resources found in default namespace
```

> **📢 旁白（攔截成功後說）**：「看到差別了嗎？同一份 YAML，裝上 Policy 之後直接在 API 層被拒絕，Pod 根本沒有機會被調度到 Node 上。這就是『爆炸半徑為零』——不是建立後再刪除，而是從一開始就不存在。」

------

### Step 3｜攔截非法映像檔來源 ⚡

```powershell
kubectl run test-nginx --image=nginx
```

> **預期報錯**：
>
> ```
> Error from server: admission webhook "validate.kyverno.svc-fail" denied the request:
> policy Pod/default/test-nginx for resource violation:
> disallow-privileged-containers/check-image-registry:
> 不允許使用未經授權的映像檔來源！請使用 ghcr.io 或官方來源。
> ```

```powershell
# 即時確認 Pod 完全沒有被建立
kubectl get pods
# 預期：No resources found in default namespace
```

> **📢 旁白（攔截成功後說）**：「`nginx` 這個映像來自 Docker Hub，不在我們的白名單內，直接被擋下來。這是供應鏈安全的實踐——攻擊者就算入侵了工程師的電腦，也無法把惡意映像部署進叢集。」

------

### Step 4｜技術原理總結

#### Kyverno 擋關四部曲

| 步驟       | 動作                                      | 說明                        |
| ---------- | ----------------------------------------- | --------------------------- |
| 1️⃣ 建立政策 | `kubectl apply -f 07-kyverno-policy.yaml` | 寫明禁止規則，全叢集生效    |
| 2️⃣ 提交請求 | `kubectl apply -f 03-bad-pod.yaml`        | 工程師嘗試建立違規 Pod      |
| 3️⃣ 海關攔截 | API Server 詢問 Kyverno                   | 「這 Pod 符合安全規定嗎？」 |
| 4️⃣ 拒絕入境 | Kyverno 回傳 Forbidden                    | Pod 完全不會被建立          |

> **📢 收尾旁白**：
>
> - **（防禦深度）**：「許多初階 Policy 只掃主容器，忽略了 `initContainers`。攻擊者可以把特權設定藏在初始化容器裡繞過檢查。我們的 Policy 兩者都掃，真正做到滴水不漏。」
> - **（高可用考量）**：「Policy 特別排除了 `kube-system` 和 `kyverno` 命名空間。K8s 底層的網路和儲存外掛本來就需要特權模式，若不設白名單，嚴格的 Policy 會誤殺系統核心元件導致叢集崩潰。這是安全與高可用性平衡的考量。」
> - **（左移資安）**：「資安不再是部署後才掃描，而是在部署當下的 Admission Time 直接擋掉。Policy as Code，讓安全準則進入 Git，實現 24/7 自動化治理。」

------

### 🧹 收尾清理

```powershell
# 清除測試 Pod（含意外建立的情況）
kubectl delete pod test-nginx bad-pod-security-violation --ignore-not-found

# 移除 Policy（維持環境獨立性，確保下次演示從零開始）
kubectl delete clusterpolicy disallow-privileged-containers --ignore-not-found

# 確認環境乾淨
kubectl get pods
kubectl get clusterpolicy
# 預期：兩者均回傳 No resources found
```

> **⚠️ 特別注意（跨場景資源保留）**：
>
> | 資源                  | 本場景結束後 | 原因                           |
> | --------------------- | ------------ | ------------------------------ |
> | `pvc ebs-claim`       | ✅ **保留**   | 場景四、場景十依賴             |
> | Kyverno 控制器本身    | ✅ **保留**   | 只刪 Policy，不刪 Kyverno 安裝 |
> | Argo Rollouts / Trivy | ✅ **保留**   | Bootstrap 安裝，後續場景依賴   |
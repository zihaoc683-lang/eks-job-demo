## 🎭 場景五：資安漏洞自動掃描 (Trivy Operator)

**📂 涉及檔案**：平台組件，由 `bootstrap-platform.ps1` 安裝至 `trivy-system` **展示內容**：證明叢集具備持續性資安監控能力，SRE 不需切換工具即可掌握全叢集漏洞狀態。

> [!TIP] **演示意義 (SRE 講稿摘要)**：
>
> - **Runtime 安全**：資安掃描從 CI 階段延伸到容器運行時，形成完整的 DevSecOps 閉環
> - **Security as Data**：掃描結果轉化為 K8s 原生資源，用 `kubectl` 就能審計，無需額外工具
> - **持續監控**：事件驅動，新 Pod 生成立即觸發掃描，並定時複查（預設 24h）確保發現最新漏洞

------

### ⚠️ 演示前置作業

```powershell
# 確認 Trivy Operator 本身健康，才能保證掃描報告存在
kubectl get pods -n trivy-system
# 預期：trivy-operator-xxx 狀態為 Running
```

> [!CAUTION] **若 Pod 非 Running 或不存在**：重新執行 Bootstrap 第四步：
>
> ```powershell
> kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/aquasecurity/trivy-operator/main/deploy/static/trivy-operator.yaml
> ```
>
> 安裝完成後等待 **1～3 分鐘**讓初次全盤掃描完成，再繼續演示。

------

### 運作原理（開場白）

> **📢 開場旁白**：「Trivy Operator 以三個機制實現持續性資安監控：
>
> - **事件驅動**：監聽 K8s API，一旦有新 Pod 生成立即觸發掃描任務
> - **資源化報告**：掃描結果轉化為 K8s 的 Custom Resource，讓 SRE 用原生 `kubectl` 指令審計
> - **持續複查**：預設每 24 小時重新掃描，確保能捕捉最新公告的零日漏洞（Zero-day）」

------

### Step 1｜查看全叢集漏洞報告總覽

```powershell
kubectl get vulnerabilityreports -A -o wide
# 預期：列出所有 namespace 下的掃描報告
# 每一行對應一個容器映像，包含 CRITICAL / HIGH / MEDIUM / LOW / UNKNOWN 各欄位數字
```

> **預期輸出格式**：
>
> ```
> NAMESPACE      NAME                                          REPOSITORY                     TAG        SCANNER  AGE    CRITICAL  HIGH  MEDIUM  LOW  UNKNOWN
> argo-rollouts  replicaset-argo-rollouts-...                 argoproj/argo-rollouts         v1.9.0     Trivy    120m   0         2     5       1    0
> kube-system    replicaset-coredns-...-coredns               eks/coredns                    v1.11.4    Trivy    120m   0         1     3       0    0
> ...
> ```

> **📢 旁白**：「每一行對應叢集中一個正在運行的容器映像。HIGH 以上的欄位不為零，就是需要優先追蹤的項目。值得注意的是，我們這個叢集的 CRITICAL 數量很少，這代表映像版本管理做得好——大部分元件都保持在較新的版本。但 HIGH 等級的漏洞仍然存在，這正是我們接下來要深入查看的。」

------

### Step 2｜查看特定 Namespace 的漏洞報告

```powershell
# kube-system 是系統核心元件，最值得關注
kubectl get vulnerabilityreports -n kube-system -o wide
# 預期：列出 CoreDNS、kube-proxy、EBS CSI Driver 等系統元件的掃描報告
# 延伸說明：若已部署 Prometheus 等監控組件，monitoring namespace 也會有報告
kubectl get vulnerabilityreports -n monitoring
# 若回傳 No resources found，這是正常的：有 Pod 才有掃描，證明報告是即時且真實的
```

> **📢 旁白**：「`monitoring` namespace 如果查無資源，不是 Trivy 壞了，而是那個 namespace 目前沒有運行中的 Pod。這正好證明 Trivy 的報告是事件驅動、即時產生的，不是預先寫死的假資料。」

------

### Step 3｜深入查看漏洞細節 ⚡

```powershell
# 透過 Select-String 過濾 CVE 編號與嚴重等級，取前 15 筆
kubectl get vulnerabilityreports -n kube-system -o yaml | Select-String -Pattern "vulnerabilityID|severity" | Select-Object -First 15
```

> **預期輸出**：
>
> ```
>       severity: HIGH
>       vulnerabilityID: CVE-2026-4046
>       severity: HIGH
>       vulnerabilityID: CVE-2026-4046
>       severity: CRITICAL
>       vulnerabilityID: CVE-2025-68121
>       severity: HIGH
>       vulnerabilityID: CVE-2025-61726
>       severity: HIGH
>       vulnerabilityID: CVE-2025-61728
> ```

> **📢 旁白（步驟三完成後說）**： 「每一筆都有精確的 CVE 編號和嚴重等級。你可以看到這裡出現了一筆 CRITICAL——`CVE-2025-68121`。維運人員看到這份清單，可以直接查詢 CVE 資料庫了解攻擊向量，再決定是否升級映像版本。
>
> 同時注意到大部分都是 HIGH 而非 CRITICAL，這說明我們的元件版本管理是有效的——但 HIGH 等級同樣不能忽視，特別是在面向公網的服務上。這就是 Security as Data 的價值：資安狀態變成可查詢、可追蹤的結構化資料，而不是只有 CI 掃描通過就算安全。」

------

### Step 4｜進階技術說明

> **📢（DevSecOps 閉環）**：「在真實生產環境中，我會將 Trivy 與 Kyverno 聯動。Trivy 發現 CRITICAL 漏洞後，Kyverno Policy 自動禁止該映像的 Pod 繼續執行，形成『掃描 → 發現 → 自動阻斷』的安全治理閉環，不需要人工介入。」

------

### 🧹 收尾清理

> **本場景無需執行任何清理指令。**

Trivy Operator 是背景監控組件，持續運行是預期行為：

- 後續場景新增的 Pod 會自動被掃描並產生新報告
- 不影響其他場景的演示
- 勿執行 `kubectl delete` 刪除 `trivy-system` 下的資源

> **⚠️ 特別注意（跨場景資源保留）**：
>
> | 資源                    | 本場景結束後 | 原因                         |
> | ----------------------- | ------------ | ---------------------------- |
> | `trivy-system` 所有組件 | ✅ **保留**   | 持續背景監控，後續場景依賴   |
> | `pvc ebs-claim`         | ✅ **保留**   | 場景十依賴                   |
> | Kyverno / Argo Rollouts | ✅ **保留**   | Bootstrap 安裝，後續場景依賴 |
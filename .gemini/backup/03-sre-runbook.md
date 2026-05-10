# 🚨 SRE 故障排查與災難復原手冊 (SRE Runbook & DR Strategy)

本手冊定義了平台工程與 SRE 團隊在面臨生產環境突發事件 (Incidents) 時的標準作業程序 (SOP)。目標是透過高度結構化的排障思維，將 MTTR (平均修復時間) 降至最低。

## 🎯 故障排查核心心法 (Troubleshooting Philosophy)

在面對任何微服務與 K8s 異常時，我們遵循 **「由外而內、由上而下」** 的排查原則：
1. **L7/L4 網路層**：DNS 解析是否正常？ALB/NLB 健康檢查是否通過？憑證是否過期？
2. **K8s 服務層**：Service 的 Endpoints 是否存在且對應到正確的 Pod IPs？
3. **K8s 運算層**：Pod 的狀態是否為 Running？有沒有 OOMKilled 或 CrashLoopBackOff？
4. **系統底層**：節點的 CPU/Memory 是否耗盡？EBS 磁碟是否卡在 Pending？

---

## 🛠️ 常見情境排障 SOP

### 情境 1：Pod 狀態為 CrashLoopBackOff
**發生原因**：應用程式啟動失敗，或是 Liveness Probe 探針失敗導致 K8s 不斷重啟容器。
**排查步驟**：
1. **看日誌找根因**：
   ```bash
   kubectl logs <pod-name> --previous
   ```
   *(加上 --previous 可以看到上一次當機前最後噴出的錯誤，這往往是最關鍵的線索)*
2. **檢查詳細事件**：
   ```bash
   kubectl describe pod <pod-name>
   ```
   *尋找 Events 區段，確認是否有 OOMKilled (記憶體不足) 或 Readiness probe failed。*

### 情境 2：外部無法連線 (網頁顯示 502/504)
**發生原因**：Ingress/Service 無法將流量正確路由到健康的 Pod。
**排查步驟**：
1. **確認 Endpoints**：
   ```bash
   kubectl get endpoints <service-name>
   ```
   *如果沒有 IP，代表 Pod 的 Label Selector 寫錯，或者 Readiness Probe 沒過。*
2. **網路連線測試 (透過臨時排障 Pod)**：
   ```bash
   kubectl run netshoot --rm -i --tty --image nicolaka/netshoot -- /bin/bash
   # 在內部執行 curl 或 telnet 測試目標 Service
   ```

### 情境 3：EBS 磁碟卡在 Pending 導致 Pod 無法調度
**發生原因**：EBS 是與可用區 (AZ) 綁定的，若 Pod 被排程到 AZ-A，但 EBS 開在 AZ-B，則會永遠掛載失敗。
**解決方案**：
檢查 StorageClass 是否有設定 WaitForFirstConsumer。這能確保 K8s 調度器先決定 Pod 要落在哪個 Node (AZ)，再通知 AWS 去正確的 AZ 建立硬碟。

### 情境 4：kubectl 執行報錯 "no such host" 或 "no matches for kind"
**發生原因**：通常發生在 IaC (Terraform) 銷毀並重建叢集後。這包含了兩個連鎖的 Day 0 錯誤：
1. **`no such host`**：本地的 `~/.kube/config` 憑證還指著「上一次建立的舊叢集 API 網址」。雖然叢集名稱相同，但底層 AWS 網址已改變。
2. **`no matches for kind "Application"`**：憑證更新後，立刻套用含有 CRD (如 Argo CD 的 `Application`) 的 YAML，但叢集卻完全是空的，連核心控制器都還沒安裝。
**解決方案 (Bootstrapping)**：
1. **更新憑證**：執行 `aws eks update-kubeconfig --region ap-northeast-1 --name <cluster-name>` 重新綁定最新 API。
2. **執行引導程序 (Bootstrap)**：在套用任何業務邏輯前，必須先確保平台組件 (如 Argo CD, Kyverno) 已就緒。請執行 `.\bootstrap-platform.ps1` 為新叢集安裝必要的 CRD 與控制器。

### 情境 5：Pod 狀態為 Pending，錯誤訊息顯示 "Too many pods"
**發生原因**：觸碰到了 AWS EKS 的 **ENI Pod Limit**。
在 AWS 中，每種實例型號都有最大 Pod 承載量（例如 `t3.small` 僅 11 個）。
*📍 **實戰案例**：本專案在執行 **「場景九：可觀測性監控」** 時，由於 Prometheus 堆疊包含多個組件，與原有的 Argo、Kyverno、Trivy 等維運工具加總後，Pod 總數超過了 3 台節點的承載上限 (33 個)，導致核心組件無法調度。*

**解決方案**：
1. **橫向擴展 (Horizontal Scale)**：修改 `eks.tf` 中的 `desired_size` 增加節點數量，分攤 Pod 壓力。
2. **開啟前綴委派 (Prefix Delegation)**：執行 `kubectl set env daemonset aws-node -n kube-system ENABLE_PREFIX_DELEGATION=true`，這能將單機配額大幅提升（如 t3.small 從 11 變為 110）。

> [!IMPORTANT]
> **💡 SRE 深層技術筆記：為什麼 Terraform apply 沒反應？**
> 在使用 `terraform-aws-modules/eks` 時，為了配合 **Cluster Autoscaler** 自動擴縮，模組內建了 `lifecycle { ignore_changes = [scaling_config[0].desired_size] }` 策略。
> **發生情境**：當我們在 **「場景九」** 發現資源不足試圖透過 Terraform 增加 `desired_size` 時，會發現 Terraform 認為「這是應該交給自動擴展器管理的屬性」而忽略變更，導致顯示 `No changes`。
> **解決方案**：在緊急情況下（如 Demo 資源不足），應直接使用 AWS CLI 強制更新：
> `aws eks update-nodegroup-config --cluster-name <name> --nodegroup-name <node-group-name> --scaling-config desiredSize=<count>`

*📢 **SRE 建議**：在 Demo 情境下，建議直接增加節點數量 (方案 1)，這最能體現 IaC 的彈性管理能力。*

### 情境 6：套用大型 YAML (如 CRD) 時出現 "metadata.annotations: Too long"
**發生原因**：`kubectl apply` 預設會將完整的物件內容存放在 Annotation 中。當部署像 Prometheus 這種超大型的自定義資源定義 (CRD) 時，會超過 K8s 的長度限制 (256KB)。
*📍 **實戰案例**：在本專案修復 **「場景九」** 缺失的 Prometheus CRD 時遇到此報錯。*
**解決方案**：
改用 **Server-side Apply**。這會將合併邏輯交給伺服器處理，不依賴本地 Annotation：
```powershell
kubectl apply --server-side -f <URL_OR_FILE>
```

---

## 🛡️ 災難復原策略 (Disaster Recovery Strategy)

對於最高優先級的 P0 系統，我們定義了極高的 RPO (復原點目標) 與 RTO (復原時間目標)。

### 1. 狀態備份 (Velero)
*   **備份對象**：Kubernetes 叢集狀態 (YAML) 與 PVC (EBS 快照)。
*   **備份機制**：透過 Velero 每日定時將資源備份至 AWS S3，並開啟 S3 的跨區域複製 (Cross-Region Replication)。
*   **復原測試**：每季進行一次 DR 演練，透過 `velero restore create --from-backup <backup-name>` 驗證能在 15 分鐘內於另一個備援 AZ 重建完整環境。

### 2. 基礎設施重建 (Terraform)
*   雲端網路、EKS 核心與 RDS 資料庫皆由 Terraform 管理。
*   若整個 AWS 帳號或區域發生毀滅性災難，我們能透過 CI/CD 管道一鍵執行 `terraform apply`，在另一個乾淨的區域中快速蓋出全新的 VPC 與 EKS 大樓，隨後再由 Velero 倒入靈魂 (數據與狀態)。

### 3. GitOps 一鍵復原
*   所有的微服務應用程式配置皆存放於 GitHub，Argo CD 作為單一真相守護者。
*   當新叢集建立完成並安裝 Argo CD 後，它將自動掃描 GitHub，並在數分鐘內將數百個微服務「自動部署並配置到位」，達成極致的自動化災難復原。
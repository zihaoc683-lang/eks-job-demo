## 場景九：可觀測性與監控 (Observability / Grafana) (⚠️ 未完成實作)

> [!WARNING]
> **🚧 實作中 (Under Construction)**
> 此場景之監控組件與儀表板尚在整合測試中，暫不建議於正式演示中使用。

> [!IMPORTANT]
> **📢 場景九前置準備：Argo CD 核心檢查 (Demo 順暢關鍵)**
>
> **為什麼這裡需要 Argo CD？**
> 場景九並非手動安裝，而是實踐 **「監控即代碼 (Observability as Code)」**。我們透過 Argo CD 統一管理複雜的 Prometheus Stack，確保監控組件的狀態與 GitHub 完全同步，避免人為設定偏移。
>
> **1. 執行部署**：`kubectl apply -f k8s/09-observability.yaml`
> **2. 故障排除 (必看 ⚠️)**：
> 由於 Prometheus 的自定義資源 (CRD) 極其龐大，常會超出 K8s 預設的註解限制 (64KB)。若 Argo CD 顯示 `Sync failed`，請務必開啟 **Server Side Apply**：
>
> *   進入 Argo CD 介面 -> `prometheus-stack` -> `APP DETAILS` -> `SYNC POLICY` -> 勾選 **`Server Side Apply`** -> 儲存並重新 **`SYNC`**。
>     **3. 等待機制**：同步開始後需約 **2-3 分鐘**，直到 `kubectl get pods -n monitoring` 看到所有組件為 `Running`。
>     **※ 提醒**：若連線斷開，請重新執行 `kubectl port-forward svc/prometheus-stack-grafana -n monitoring 3000:80`。

1. **登入 Grafana 視覺化介面**：

   * **指令 (開啟對外連線)**：

     ```powershell
     kubectl port-forward svc/prometheus-stack-grafana -n monitoring 3000:80
     ```

   * **操作**：打開瀏覽器前往 `http://localhost:3000`。

   * **帳號密碼**：帳號 `admin`，密碼 `admin` (定義於 `09-observability.yaml` 中)。

2. **展示內建儀表板 (Dashboards) — 監控要點**：

   *   登入後，點擊左側導覽列的 **Dashboards**。
   *   **推薦優先展示以下三個面板，這最能展現 SRE 的「黃金訊號 (Golden Signals)」監控思維：**
       1.  **`Kubernetes / Compute Resources / Cluster` (最直觀)**：
           *   **技術要點**：監控整個 EKS 叢集的 CPU/Memory 資源水位與健康狀況。
       2.  **`Kubernetes / Compute Resources / Namespace (Pods)` (實務應用)**：
           *   **技術要點**：選擇 `default` 或 `monitoring` 命名空間。配合壓測場景，可即時觀測 Pod 水平擴展 (HPA) 與資源消耗曲線。
       3.  **`Kubernetes / API server` (展現深度)**：
           *   **技術要點**：監控 API Server 的 Request Latency (延遲) 與 Request Rate。這是評估控制平面 (Control Plane) 健康度的關鍵指標。

3. **架構解說 (Technical Breakdown)**：

   *   📢 **架構介紹**：「在 K8s 中建立監控系統非常繁瑣，所以我選用了業界標準的 `kube-prometheus-stack` Helm Chart，並結合剛才展示的 Argo CD (GitOps) 進行管理。」
   *   📢 **架構介紹**：「大家現在看到的這些儀表板是隨插即用的。Prometheus 在背景會透過 `ServiceMonitor` 自動發現叢集內的新服務並抓取 Metrics。這意味著未來開發團隊部署新微服務時，只要加上簡單的註解，監控指標就會自動進到這個面板中，實現了『可觀測性即代碼 (Observability as Code)』。」

4. **🧹 結束展示與清理**：

   * 在執行 port-forward 的終端機視窗按下 Ctrl + C 停止連線。

   * **若找不到該視窗，用以下指令強制釋放 3000 port**：

     ```powershell
     Stop-Process -Id (Get-NetTCPConnection -LocalPort 3000 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess) -Force -ErrorAction SilentlyContinue
     echo "Port 3000 已釋放"
     ```

   * **若要確保情境獨立性 (移除監控堆疊)**：

     ```powershell
     # 刪除 Argo CD Application，Argo CD 會自動把 Prometheus 相關資源全部回收
     kubectl delete -f k8s/09-observability.yaml --ignore-not-found
     ```


---

---

## 
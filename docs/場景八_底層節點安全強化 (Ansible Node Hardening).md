了解，你想在場景八裡誠實說明 Ansible 為什麼不實際執行，但同時把它變成加分點而不是缺陷。以下是整合後的完整版：

------

## 🎭 場景八：底層節點安全強化 (Ansible Node Hardening)

**📂 涉及檔案**：`ansible/node-hardening.yml`, `bin/node-audit.ps1`, `bin/node-fix.ps1`, `bin/node-reset.ps1` **展示內容**：透過「審計 → 修復 → 驗證」SRE 閉環，確保 K8s 底層 OS 的安全性與效能。

> [!TIP] **演示意義 (SRE 講稿摘要)**：
>
> - **縱深防禦**：K8s 管容器，Ansible 管 OS，兩層防護缺一不可
> - **IaC 完整性**：Terraform 建雲端資源，Ansible 配 OS 層設定，共同實現完整的基礎設施即代碼治理
> - **Audit-Remediate-Verify 閉環**：發現問題、自動修復、驗證結果，這是 SRE 合規運作的標準流程

------

### 📖 場景說明（開場白）

> **📢 開場旁白**：「這個場景我會分兩個層次來說明。第一層是實際執行的部分——用三個腳本示範 SRE 的 Audit-Remediate-Verify 閉環。第二層是架構說明——展示生產環境真正會跑的 Ansible Playbook，以及為什麼 Demo 環境不直接執行它。」

> [!NOTE] **為什麼 `node-hardening.yml` 不在 Demo 現場實際執行？**
>
> 這不是能力問題，而是環境限制與架構設計的考量：
>
> | 限制                      | 說明                                                         |
> | ------------------------- | ------------------------------------------------------------ |
> | **Dynamic Inventory**     | EKS Node 的 IP 與 Instance ID 每次 `terraform apply` 後都會變動，靜態 `.ini` inventory 無法維護。生產環境需要 `aws_ec2.yml` Dynamic Inventory 動態查詢 AWS API |
> | **SSM Connection Plugin** | EKS Managed Node 不開放 SSH，需透過 AWS SSM Session Manager 連線，要額外安裝 `amazon.aws.aws_ssm` connection plugin |
> | **Demo 穩定性**           | Ansible 執行時間長（需連線每台 Node 逐一執行），不適合面試現場的即時展示 |
>
> **📢 面試話術**：「在真實生產環境，我會搭配 Dynamic Inventory 和 AWS SSM Connection Plugin 執行這份 Playbook。Demo 現場我用腳本模擬相同效果，讓大家在幾秒內看到結果，而不是等待 Ansible 逐台連線執行。」

------

### ⚠️ 演示前置作業

```powershell
# [關鍵] 確認 Kyverno Policy 狀態
# node-audit/fix/reset 使用的 nicolaka/netshoot 不在 Kyverno 映像白名單內
# 若 Policy 存在，三個腳本都會被 Admission Webhook 攔截導致演示失敗
kubectl get clusterpolicy disallow-privileged-containers --ignore-not-found
```

> [!CAUTION] **若上方指令有回傳 Policy 資源**：必須先移除才能繼續
>
> ```powershell
> kubectl delete clusterpolicy disallow-privileged-containers --ignore-not-found
> ```

```powershell
# 將節點參數重置為不合規狀態，確保審計階段能看到異常數值
.\bin\node-reset.ps1
# 預期：執行完後 Pod 自動刪除，somaxconn 回到 128
```

------

### Step 1｜🔍 合規性審計 (Audit)

```powershell
.\bin\node-audit.ps1
# 預期輸出：
# >>> Current Node Setting:
# net.core.somaxconn = 128
```

> **📢 旁白**：「身為 SRE，我們不能只管容器，底層節點的健康才是穩定的基石。現在檢查發現節點的 TCP 連線隊列參數僅為預設值 128——這在高併發流量下會導致新連線被直接 Drop（丟包）。接下來用自動化腳本修復，模擬 Ansible 在生產環境的執行結果。」

> **💡 說明**：腳本執行完畢後會自動刪除診斷 Pod，這體現 Ephemeral Pod 的維運思維——工具用完即丟，不佔用叢集資源。

------

### Step 2｜🛠️ 自動化修復 (Remediation)

```powershell
.\bin\node-fix.ps1
# 預期：執行完後 Pod 自動刪除
```

> **📢 旁白**：「執行修復腳本，將加固參數 `1024` 即時套用到節點。這個腳本模擬生產環境 Ansible Playbook 的執行效果——在真實場景中，Ansible 會同時將設定寫入 `/etc/sysctl.conf`，確保重開機後持久生效，並一次套用到叢集中所有 Node，消除配置偏移的風險。」

------

### Step 2.5｜📄 展示 Ansible Playbook 架構

**操作**：在編輯器或 GitHub 上打開 `ansible/node-hardening.yml`

> **📢 旁白**：「剛才的腳本是 Demo 用的即時修復。在真實生產環境，我們會執行這份 Ansible Playbook，搭配 Dynamic Inventory 自動抓取所有 EKS Node，透過 AWS SSM 無密鑰連線逐台執行。它做的事情更完整：
>
> - **Task 1**：自動更新所有 OS 套件，修補已知 CVE
> - **Task 2**：預裝 htop、tcpdump、jq 等標準維運工具，確保每台 Node 都有一致的排障能力
> - **Task 3**：統一時區為 Asia/Taipei，確保跨 Node 的日誌時間戳一致，方便事故追蹤
> - **Task 4**：寫入 `/etc/sysctl.conf` 確保 `somaxconn=1024` 重開機後持久生效
> - **Task 5**：確保 SSM Agent 運行，取代傳統 SSH，實現無密鑰的安全節點存取
>
> 這就是 IaC 完整治理的實踐——不只是修一個參數，而是把整個節點的安全基準定義成代碼，一次套用到所有 Node，消除配置偏移的風險。」

> **📢（若被問到為什麼不直接跑 Ansible）**：「這個 Demo 環境的 EKS Node 每次重建 IP 都會變，需要搭配 Dynamic Inventory 動態查詢 AWS API 才能執行。另外 EKS Managed Node 不開放 SSH，需要透過 SSM Connection Plugin 連線。這些設定在生產環境是標準配置，但在 Demo 現場設定起來需要額外時間，所以我用腳本模擬相同效果，確保展示的流暢性。這個 Playbook 本身是完整可執行的，架構設計是生產就緒的。」

------

### Step 3｜✅ 最終驗證 (Verification)

```powershell
.\bin\node-audit.ps1
# 預期輸出：
# >>> Current Node Setting:
# net.core.somaxconn = 1024
```

> **📢 旁白**：「修復完成後重新審計，數值已從 128 提升至 1024。這是一個完整的 Audit → Remediate → Verify 閉環，確保系統符合預期的安全基準。這套流程可以被排程化，實現定期合規性自動驗證。」

------

### 🔍 技術原理說明

> **📢（為什麼選 `net.core.somaxconn`）**：「它定義了 Socket 監聽隊列的上限。預設 128 是 Linux 核心從數十年前沿用至今的設定，設計當時的網路流量遠低於現代微服務架構。提升至 1024 是確保叢集生產就緒（Production Ready）的標準動作。」

> **📢（為什麼不直接 SSH 進去改）**：「叢集有多台 Node，手動逐台修改不只費時，還容易產生配置偏移——A 台改了，B 台忘了改。Ansible 一個指令套用到所有 Node，確保環境一致性，這就是配置管理的核心價值。」

> **📢（Ephemeral Pod 維運思維）**：「這三個腳本使用臨時 Pod 執行維運任務，不需要在節點上預裝任何 Agent。隨插即用、用完即丟，這體現了雲原生維運的『無代理程式 (Agentless)』思維。」

------

### 📂 涉及檔案與技術角色

| 檔案                         | 角色                     | 功能                                                         |
| ---------------------------- | ------------------------ | ------------------------------------------------------------ |
| `ansible/node-hardening.yml` | 架構說明 (IaC Reference) | 定義節點加固的完整最終狀態，生產環境實際執行的 Playbook，Demo 現場僅作展示 |
| `bin/node-audit.ps1`         | 審計工具 (Audit)         | 檢查節點目前的 `net.core.somaxconn` 數值                     |
| `bin/node-fix.ps1`           | 修復工具 (Remediate)     | 即時將 `somaxconn` 提升至 1024，模擬 Ansible Task 4          |
| `bin/node-reset.ps1`         | 重置工具 (Cleanup)       | 將系統推回不合規狀態，供重複演示使用                         |

------

### 🧹 收尾清理

> **本場景無需執行額外清理指令。**

- 三個腳本執行完畢後均會自動刪除對應 Pod
- 加固狀態（`somaxconn = 1024`）保留，證明演示成功
- 若需重複演示，執行 `.\bin\node-reset.ps1` 即可還原

> **⚠️ 特別注意（跨場景資源保留）**：
>
> | 資源                            | 本場景結束後 | 原因                                         |
> | ------------------------------- | ------------ | -------------------------------------------- |
> | `pvc ebs-claim`                 | ✅ **保留**   | 場景十依賴                                   |
> | Kyverno / Trivy / Argo Rollouts | ✅ **保留**   | Bootstrap 安裝，後續場景依賴                 |
> | Kyverno Policy                  | ⚠️ **視情況** | 本場景前若有刪除，後續場景若需要需重新 apply |
> | Node 加固狀態                   | ✅ **保留**   | 節點重開機前持續生效                         |
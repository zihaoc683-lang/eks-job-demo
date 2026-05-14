## 🎭 場景六：DevSecOps CI 管道 (GitHub Actions)

**📂 涉及檔案**：`.github/workflows/security-scan.yml`, `.github/workflows/terraform-ci.yml` **展示內容**：展示「左移資安 (Shift-Left)」，純瀏覽器畫面展示，無需任何 K8s 指令。

> [!TIP] **演示意義 (SRE 講稿摘要)**：
>
> - **左移資安 (Shift-Left)**：在代碼進入叢集之前，CI 管道就已完成安全審查，將問題攔截在源頭
> - **雙層防護**：`security-scan.yml` 守護映像與 IaC 漏洞，`terraform-ci.yml` 守護基礎設施變更品質，兩者分工明確
> - **自動化合規**：安全規則寫入 Pipeline，人工 Code Review 只需關注業務邏輯，資安由機器把關

------

### ⚠️ 演示前置作業

```
瀏覽器開啟：https://github.com/zihaoc683-lang/eks-job-demo/actions
```

確認頁面上有執行紀錄後即可開始。無需任何 K8s 前置操作。

> [!CAUTION] **若頁面完全沒有執行紀錄**：代表從未有過 push 或 PR 觸發，需手動推一個空 commit：
>
> ```powershell
> git commit --allow-empty -m "chore: trigger CI"
> git push origin main
> ```

------

### 運作原理（開場白）

> **📢 開場旁白**：「這個專案有兩條 CI 管道，各自守護不同層面的安全：
>
> - **Security Scan**：每次 push 或 PR 到 main，自動用 Trivy 掃描 Terraform IaC 設定檔與 Container Image，攔截已知的 CVE 漏洞
> - **Terraform CI/CD**：每次 `.tf` 檔案變更，自動執行 Checkov 靜態分析與 Terraform Plan 預覽，確保基礎設施變更在套用前已通過安全審查
>
> 兩條管道合在一起，形成了從代碼提交到基礎設施變更的完整安全閘門。」

------

### Step 1｜查看 Security Scan Workflow

**操作**：點擊左側 `Security Scan` → 點開最新一筆執行紀錄

> **觸發條件**：push 或 PR 到 `main` branch 時自動觸發，無論變更哪個檔案

展示兩個 Job 的結果：

**Job 1：IaC 掃描（Terraform 設定檔）**

> **📢 旁白**：「第一個 Job 用 Trivy 的 config 模式掃描所有 `.tf` 檔案，檢查 IaC 設定是否存在已知的 Misconfiguration——例如 S3 未加密、Security Group 開放了 0.0.0.0/0。這是『基礎設施即代碼』的資安實踐：不只應用程式映像需要掃描，連建出這個環境的 Terraform 代碼本身也要過關。」

**Job 2：Container Image 掃描**

> **📢 旁白**：「第二個 Job 掃描我們實際部署的映像 `stefanprodan/podinfo:6.2.3`，列出 CRITICAL 和 HIGH 等級的 CVE。注意這裡的 `exit-code: 0`——這是 Demo 模式，讓管道顯示報告但不強制失敗。在真實生產環境，我會把它改成 `exit-code: 1`，一旦發現 CRITICAL 就直接中斷部署，阻止有漏洞的映像進入叢集。」

------

### Step 2｜查看 Terraform CI/CD Workflow

**操作**：點擊左側 `Terraform CI/CD (Multi-Tool Demo)` → 點開最新一筆執行紀錄

> **觸發條件**：push 或 PR 到 `main`，且變更包含 `.tf` 檔案時才觸發

展示四個步驟：

| 步驟                   | 工具                   | 作用                                                  |
| ---------------------- | ---------------------- | ----------------------------------------------------- |
| Terraform Format Check | `terraform fmt -check` | 確保代碼格式一致，格式不符直接失敗                    |
| Checkov Security Scan  | Checkov                | 對照 CIS Benchmark 靜態分析，列出所有 FAILED 項目     |
| Terraform Init & Plan  | Terraform              | 預覽基礎設施變更，`-backend=false` 避免連接真實 State |
| PR Comment             | GitHub Script          | 自動將 Plan 結果貼回 PR，Reviewer 不需本地執行        |

> **📢 旁白（展示 Checkov 結果時說）**：「Checkov 對照 CIS Benchmark 逐條檢查。看到 FAILED 的項目不要緊張，這正是它應該做的事——把潛在風險在進入生產環境前列出來。`soft_fail: true` 是 Demo 環境的設定，生產環境移除後，任何 FAILED 都會直接中斷部署。」

> **📢 旁白（展示 PR Comment 功能時說）**：「如果這是一個 PR，Terraform Plan 的結果會自動被貼回 PR 的留言區。Reviewer 不需要在本地 `terraform plan`，直接在 GitHub 上就能看到這次變更會動到哪些雲端資源，大幅降低基礎設施變更的審查門檻。」

------

### Step 3｜紅燈處理（若看到失敗紀錄）

> [!TIP] **看到紅燈不要慌，這反而是加分機會：**
>
> **📢 旁白**：「這條管道顯示失敗，代表 Pipeline 成功抓到了不符合規範的代碼——例如 S3 Bucket 未加密、或 Security Group 開放了 0.0.0.0/0——並在進入生產環境前將其擋下。這正是 DevSecOps 的核心價值：與其在生產環境出事後修補，不如在 CI 階段就自動攔截。紅燈在這裡不是失敗，是系統正常運作的證明。」
>
> **操作**：點開失敗的 Job → 找到 Checkov 掃描結果 → 展示 `FAILED` 項目清單

------

### 🧹 收尾清理

**本場景無需執行任何清理指令。**

純瀏覽器展示，不影響叢集狀態，展示完畢直接進入下一場景。

> **⚠️ 特別注意（跨場景資源保留）**：
>
> | 資源                            | 本場景結束後   | 原因                         |
> | ------------------------------- | -------------- | ---------------------------- |
> | GitHub Actions 紀錄             | ✅ **自動保留** | 平台管理，無需處理           |
> | 叢集所有組件                    | ✅ **不受影響** | 本場景未操作任何 K8s 資源    |
> | `pvc ebs-claim`                 | ✅ **保留**     | 場景十依賴                   |
> | Kyverno / Trivy / Argo Rollouts | ✅ **保留**     | Bootstrap 安裝，後續場景依賴 |
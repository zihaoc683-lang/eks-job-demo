# 🚀 EKS 平台工程演示手冊

本手冊為本專案的主線實戰展示，設計目標：**30 分鐘內流暢展示 EKS 核心價值**。每個步驟均包含操作指令、技術說明及架構解析。

> [!NOTE]
> **📚 專案文件導覽 (Index)**
> - [01. 專案架構與技術決策](01-project-architecture.md) (核心文檔)
> - [02. 平台工程演示手冊](02-demo-guide.md) (您目前所在位置)
> - [03. SRE 故障排查與災難復原手冊](03-sre-runbook.md) (架構穩健性)
> - [04. 雲端成本優化分析](04-cost-analysis.md) (FinOps)
> - [05. 技術架構常見問題與決策解析](05-technical-faq.md) (架構深度)

---

## <mark>🛠️ 準備階段 (絕對不可跳過 ⚠️)</mark>

> [!CAUTION]
> **【警告：所有情境的共同前提】**
> 無論您今天要展示場景一還是場景九 (⚠️ 目前未完成實作)，**底下的 0.1 到 0.3 步驟絕對不能跳過！**
> 如果您剛跑完 `terraform apply` 重建叢集，您的叢集是完全空白的。跳過這些步驟會導致：
> 1. `kubectl` 報錯 `no such host` (未更新憑證)。
> 2. 部署 K8s YAML 時報錯 `no matches for kind` (未安裝 Argo CD 或 Kyverno 的 CRD)。

### 0.0 環境檢查與身份驗證 (Connectivity)
*   **指令**：`aws sts get-caller-identity`
*   **意義**：確認目前終端機已正確連線至 AWS 帳號，避免因憑證過期導致 Demo 中斷。

### <mark>0.1 基礎設施建置 (IaC)</mark>
*   **📂 涉及檔案**：`*.tf` (主結構定義)
*   **指令**：
    1. `terraform init`
    2. `terraform apply -auto-approve`
    *(若叢集已建好可跳過此步驟)*
*   **意義**：自動化建立 VPC 網路、EKS 叢集與必要的 IAM 權限。

### <mark>0.2 取得叢集控制權 (Connectivity Upgrade) 🔑</mark>
*   **指令**：`aws eks update-kubeconfig --region ap-northeast-1 --name ecommerce-eks-demo`
*   **檢查**：`kubectl get nodes` (確認所有 Node 狀態為 **Ready**)
*   **意義**：將雲端 EKS 的連線憑證下載至本地。**每次重建叢集後必跑！**

### <mark>0.3 平台引導 (Bootstrap) 🚀</mark>
*   **📂 涉及檔案**：`bootstrap-platform.ps1`
*   **指令**：`.\bootstrap-platform.ps1`
*   **意義**：一鍵佈署「維運鐵三角」，為空白的叢集注入「靈魂」。



#### 🔍 小白也能懂：這個腳本到底裝了什麼？

| 安裝組件                       | 形象化比喻           | 實質作用 (為什麼需要？)                                      | 安裝位置 (Namespace) |
| :----------------------------- | :------------------- | :----------------------------------------------------------- | :------------------- |
| **Metrics Server**             | **叢集的溫度計**     | 監控 Pod 的 CPU/記憶體。**沒有它，自動擴縮 (HPA) 就會失效。** | `kube-system`        |
| **Argo Rollouts**              | **叢集的交通指揮官** | 實現金絲雀 (Canary) 與藍綠部署。**沒有它，無法做到零停機發版。** | `argo-rollouts`      |
| **Kyverno**                    | **叢集的法官**       | 以政策 (Policy) 強制執行安全規則，例如禁止使用 `latest` 映像標籤。 | `kyverno`            |
| **Trivy Operator**             | **叢集的資安掃描儀** | 自動掃描所有 Pod 的映像漏洞 (CVE)，並產生報告。              | `trivy-system`       |
| **Argo CD**                    | **叢集的自動同步器** | 監控 Git Repo，自動將程式碼變更同步至叢集，實現 GitOps 流程。 | `argocd`             |
| **EBS Storage (StorageClass)** | **叢集的倉庫規格書** | 定義 Pod 申請持久化磁碟 (PVC) 時，AWS 自動建立 EBS Volume 的規格。 | `default`            |

> **💡 為什麼不用 Terraform 裝？**
>
> 雖然 Terraform 也能裝，但透過這個腳本，我們可以：
>
> 1. **極速部署**：將原本需要 20 分鐘的雲端等待縮短至 3 分鐘。
> 2. **展現自動化引導 (Bootstrapping) 能力**：透過腳本實現全自動化平台建置，減少人為操作風險。
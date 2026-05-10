# 核心工作能力對應：DevOps / SRE 工程師 (金融/電商) 

本文件旨在快速映射 **[AWS EKS 高可用電商基礎設施專案](../README.md)** 中，各項架構設計與實作是如何直接回應您的職缺需求。

---

## 🔹 核心要求對應 (Core Requirements)

### 1. Kubernetes 容器管理平台建置與導入容器化安全工具
- **平台建置與災備 (DR)**：本專案使用 Terraform 完整定義了從網路到運算實體的 IaC 建置。不僅如此，透過導入 **Velero**，將叢集狀態與資料庫持久卷 (EBS) 自動備份至 AWS S3，展示了企業級架構處最重要的「災難復原」底線防禦。
- **安全防禦網 (DevSecOps + Micro-segmentation + Admission Control)**：
  - **K8s 原生 API 攔截 (Kyverno)**：導入了 Policy-as-Code 概念。即使是最高權限的維運人員，若嘗試部署帶有「特權 (Privileged)」的危險容器，也會在 K8s API 接收層被直接封殺，實現系統級的強制合規。
  - **運行時安全**：透過 `06-network-policy.yaml` 實作「零信任網路微隔離 (Default Deny)」，從 K8s 網路底層斬斷內網橫向攻擊的可能性。
  - **掃描機制**：引入 `trivy-operator` 進行常規漏洞掃描；管線中也實作了針對 Image 與 IaC (Checkov) 的事前攔截。

### 2. Kubernetes 集群的運行和維護、性能調校、問題排除等
- **運行與調校**：利用 **Metrics Server** 搭配 **Horizontal Pod Autoscaler (HPA)**，成功模擬並實作了高併發流量下的自動水平擴縮容 ([見實戰演示 02-demo-guide.md](./02-demo-guide.md))。
- **AIOps 智能排障**：部署了 **K8sGPT Operator**。當叢集發生異常崩潰時，能呼叫 LLM 進行秒級的日誌分析與排障建議，極大地壓縮了 MTTR (平均修復時間)，並兼顧企業地端 LLM 的資安限制。
- **問題排除**：記錄了實踐過程中的多項疑難排解 (如 VPC 刪除死結處理、EBS 跨可用區連線問題解決方案)([見技術反思 03-reflection.md](./03-reflection.md))。

### 3. 自動化流程完善 SDLC 機制 (DevSecOps) 與安全掃瞄工具
- **Azure DevOps 管線展示**：本專案根目錄附帶 `azure-pipelines.yml`，實作了一條標準的 DevSecOps 流程：
  1. **IaC 安全掃瞄 (Checkov)**：確保基礎設施代碼無錯誤配置。
  2. **K8s Manifest 靜態掃瞄 (Kube-linter)**：保證佈署檔符合最佳實踐。
  3. **自動化測試 (K6 / Pytest)**：保證發佈品質。
  4. **映像檔建置與漏洞掃瞄 (Trivy)**：針對重度資安漏洞阻止佈署。

---

## 🌟 加分項目實用展示 (Bonus / High-Value Skills)

### 1. 具金融業相關開發/維運經驗 與 相關法規知識
在金融業，**「最小權限原則」(Principle of Least Privilege)** 以及 **「零信任」** 是合規的基石：
- 本專案揚棄直接賦予 EC2 Instance 權限的做法，而是使用 **IRSA (IAM Roles for Service Accounts)**。確切將 AWS API 權限限縮在單一 Pod 級別 (如 EBS CSI Driver 只能操作儲存資源)，這正是金融級架構的實踐。
- 透過 Public / Private Subnet 區隔，Worker Node 皆在私有網路中運行，透過 NAT Gateway 出網，最大化降低受攻擊面。

### 2. SRE 思維 - 成為 AP 與 Infra 溝通橋梁
一個成熟的 SRE 不只是維護機器，更是保障「業務穩定過渡」。本項目實作了 **Argo Rollouts (金絲雀發佈)** 策略。
當 AP 團隊交付新版本時，SRE 提供這套工具使流量按 20% -> 50% -> 100% 逐步切換。若發生錯誤，系統可自動 rollback，完美消弭了「發版即當機」的風險，成為雙方信任的橋樑。

### 3. 理解 Telemetry 概念並有建置監控與日誌系統經驗
除了基礎的 HPA Metrics 外，系統內部透過 Helm 集成了 **kube-prometheus-stack**。
這確保了從 Kubernetes Node 負載、Pod 網路流量延遲到 API 回應狀態，皆能透過 Prometheus 抓取並呈現在 Grafana 的大屏上，滿足 Telemetry 的三本柱：Metrics 的收集與預警需求。

### 4. 具建置 CI/CD pipeline 或 GitOps 經驗
專案同時採用了 GitOps 思想。透過 `azure-pipelines.yml` 更新 Repo 後，利用 Argo 工具家族 (ArgoCD / Argo Rollouts) 自動監聽 Git 儲存庫的變化並同步至叢集，實現了宣告式的快速佈署機制。

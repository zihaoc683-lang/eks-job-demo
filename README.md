# 電商巔峰：應對高併發流量的 AWS EKS 彈性架構與金絲雀部署方案

本專案展示一個基於雲端原生理念構建的高可用電商基礎設施。透過 Infrastructure as Code (IaC)、Progressive Delivery 佈署技術、**DevSecOps 自動化管線** 以及 **Telemetry 全鏈路監控系統**，模擬處理極端流量波動並符合金融級資安標準的真實運維場景。

---

## 專案導覽說明

為了便於深入了解此架構，我將技術文檔分為三個階段，建議按此順序參閱：

### 1. [技術架構深度解析](./docs/01-architecture.md)
探討 EKS 叢集設計、VPC 網路佈局以及透過 IRSA 實踐的權限控制模型。

### 2. [運維展示與實戰指南](./docs/02-demo-guide.md)
包含自我修復、金絲雀發佈、HPA 自動擴縮與數據持久化掛載的具體展示流程。

### 3. [故障排除與技術反思](./docs/03-reflection.md)
紀錄開發過程中遇到的 VPC 刪除死結、EBS 跨可用區限制等挑戰及其解決方案。

### 4. 🌟 [DevOps/SRE 職能對應展示](./docs/05-jd-mapping-sre.md)
**[ 強烈推薦 ]** 紀錄本專案如何直接對應金融業與電信業 (如台灣大哥大) 的高可用度 DevOps/SRE 工程師關鍵職缺要求。

### 5. 🚀 [台灣大哥大面試專屬攻略套件](./Taiwan-Mobile-Interview-Kit/00-INDEX.md)
**[ 面試必看 ]** 專為「Kubernetes 平台工程師」職缺整理的技術文件，包含 SOP、治理機制與排障 Runbook。

---

## 快速啟動指南

1. 基礎設施建置
   ```bash
   terraform init
   terraform apply -auto-approve
   ```

2. 叢集連線與應用部署
   ```bash
   aws eks --region ap-northeast-1 update-kubeconfig --name ecommerce-eks-demo
   kubectl apply -f k8s/
   ```

3. 執行安全掃描
   ```bash
   # 查看 Github Actions 工作流中的 Trivy 掃描結果
   ```

---

## 專案結構說明

```text
.
├── Taiwan-Mobile-Interview-Kit/ # (新增) 台灣大面試攻略與 SOP 套件
├── vpc.tf                      # 網路基礎設施 (NAT, Subnets, Routing)
├── eks.tf                      # EKS 叢集與節點組管理
├── helm.tf                     # 基礎組件 (Argo Rollouts, Metrics Server)
├── cleanup.tf                  # (核心) 自動化資源回收與防止死結邏輯
├── k8s/                        # Kubernetes 配置檔案 (01-12)
│   ├── 02-rollout.yaml         # 金絲雀發布 (Argo Rollouts)
│   ├── 07-kyverno-policy.yaml  # 政策即代碼 (Governance)
│   └── 12-monitoring.yaml      # 觀測性治理 (Prometheus)
├── .github/workflows/          # (新增) CI 安全掃描流水線 (Trivy)
├── docs/                       # 專案技術文檔
└── images/                     # 架構圖與技術圖表
```

---

## 系統架構圖例

![AWS EKS Modern Platform Architecture](./images/aws-architecture-modern.png)

---
*本專案旨在展示雲端運維與架構設計能力，代碼中包含詳細的技術註解。*

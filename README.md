# ☁️ EKS Platform Engineering Demo 🚀

這是一個具備生產級別 (Production-Ready) 架構的 EKS 平台工程專案。本專案結合了基礎設施即代碼 (Terraform)、組態管理 (Ansible)、持續交付 (Argo CD GitOps) 與自動化政策治理 (Kyverno)，展示了現代微服務架構的最佳實踐。

## 📚 專案核心文件導覽 (Documentation Index)

為了方便面試與技術交流，所有核心知識與實戰操作皆已收斂至 docs/ 目錄下的 5 份核心文件：

- [01. 專案架構與技術決策 (Project Architecture)](docs/01-project-architecture.md)
  *本專案的架構藍圖、技術選型深度比較 (如 Argo CD vs Jenkins, Kyverno vs OPA)，以及資安合規與多層次防禦設計。*

- [02. 平台工程演示手冊 (Demo Guide)](docs/02-demo-guide.md)
  *30 分鐘主線實戰演練，包含基礎設施建立、HPA 壓力測試、金絲雀發布回滾、配置偏移修復 (Drift Detection) 等動態展示腳本。*

- [03. SRE 故障排查與災難復原 (Runbook & DR)](docs/03-sre-runbook.md)
  *針對生產環境常見情境 (如 CrashLoopBackOff, 502/504, 磁碟 Pending) 的排障 SOP，以及結合 Velero 的災難復原策略。*

- [04. 雲端成本優化分析 (Cost Analysis)](docs/04-cost-analysis.md)
  *以 FinOps 視角出發，解析本專案在 AWS 上的成本分佈，以及在生產環境中降低雲端帳單的進階優化策略。*

- [05. 面試攻防教戰手冊 (Interview Prep)](docs/05-interview-prep.md)
  *提煉 DevOps / 雲端工程師常見 JD 要求的對應策略、經典面試 QA (如網路排障、IaC 狀態鎖定)，以及架構設計的自我反思。*

---
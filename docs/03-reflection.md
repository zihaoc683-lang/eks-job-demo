# 故障排除與技術反思 (Reflection & Insights)

真正的工程價值往往體現在解決問題的過程中。本文件紀錄了在建置此 EKS 專案時遇到的關鍵技術挑戰，以及對應的解決方案。

---

## 🧗 核心技術挑戰與決策

### 1. VPC 刪除死結 (DependencyViolation)
*   **挑戰**：刪除 EKS 叢集時，由於 K8s 產生的 ELB 或 ENI 尚未釋放，導致 Terraform 在刪除 VPC 安全群組或 Subnet 時發生報錯。
*   **解決方案**：
    1.  **自動化腳本**：在 `cleanup.tf` 中使用 `null_resource` 與 `kubectl delete` 在 EKS 消失前先強制清理 K8s 資源。
    2.  **相依性鏈 (Dependency Chain)**：建立 `module.eks -> time_sleep -> module.vpc` 的顯式相依性。
    3.  **緩衝等待**：透過 `time_sleep` 在 EKS 刪除後強制等待 60 秒。
*   **結果**：實現了 100% 自動化的環境回收，將 MTTR 降至最低，展現了對雲端資源生命週期的深度掌控。

### 2. EBS 儲存卷的跨可用區掛載限制
- **問題描述**：Pod 持續處於 Pending 狀態，報錯顯示 `multi-attach error` 或可用區不匹配。
- **根本原因**：AWS EBS 磁碟是綁定在單一可用區 (AZ) 的。若 Pod 被調度到 AZ-a，而硬碟位在 AZ-b，掛載就會失敗。
- **解決方案**：配置 StorageClass 的 `volumeBindingMode: WaitForFirstConsumer`。這讓 K8S 「先決定 Pod 在哪裡，再到對應的可用區建立硬碟」，解決了拓樸不一致的問題。

### 3. IRSA 授權機制與身份橋接 (Identity Bridging)
- **問題描述**：Pod 日誌顯示無法存取 AWS API，導致磁碟掛載失敗。
- **診斷過程**：雖然建立了 IAM 角色，但 Service Account 的信任關係 (Trust Policy) 內的 OIDC ID 與實際值有些微差異。
- **解決方案**：精確校對 OIDC Provider 的指紋與 ARN，落實「Pod 级别」的精確權限控制，取代傳統過大的「Node 级别」授權。

---

## 📈 未來架構演進建議

雖然目前的架構已能支撐核心營運需求，但從生產環境的角度來看，仍有以下擴展方向：
1. **全方位監控**：導入 Prometheus 與 Grafana 的深度整合，實踐基於指標 (Metric) 的自定義擴縮容。
2. **成本優化**：考慮在非核心節點組導入 AWS Spot Instances，以大幅降低測試環境的開銷。
3. **網格管理**：當微服務數量增加時，可導入 Istio 等 Service Mesh 技術處理更複雜的安全隔離。

---

## 🏆 總結
這個專案讓我學會了如何優雅地處理雲端與 Kubernetes 之間的抽象層交互。從網路隔離到狀態持久化，每一步的踩坑與填坑都強化了我對可靠架構的追求。

---
- [🏠 回到首頁](../README.md)
- [⬅️ 上一步：實戰演示指南](./02-demo-guide.md)

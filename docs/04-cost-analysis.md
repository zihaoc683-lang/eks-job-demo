# AWS EKS 專案成本分析報告

> **版本**：v1.0 | **區域**：ap-northeast-1（東京）| **幣別**：USD（美元）
> 本文件從工程師視角進行成本評估，涵蓋 Demo 環境實際花費、生產環境規模推估、成本優化策略與架構決策的財務影響。

---

## 一、成本分析總覽（Executive Summary）

本專案在設計初期即將**成本控制**列為核心設計原則之一，並透過以下三個架構決策主動管理雲端支出：

| 設計決策 | 對應的成本控制意圖 |
|---------|-----------------|
| `capacity_type = "SPOT"` | **核心省錢亮點**：使用 Spot 實例節省約 70~90% 的運算費用 |
| `single_nat_gateway = true` | Demo 環境只建一個 NAT GW，避免每 AZ 各一個造成約 2 倍費用 |
| `instance_types = ["t3.small", "t3.medium"]` | Spot 模式下混合機型，確保在低成本下仍有極高的資源獲得率 |
| `max_size = 3` | 設置 Node 數量上限，防止 HPA 測試時因 Bug 或壓測失控造成無限擴機的鉅額帳單 |

這些決策不是偶然為之，而是在設計 Terraform 時就主動做出的工程取捨，展現了**成本意識（Cost Awareness）**是雲端架構師的基本素養。

---

## 二、Demo 環境實際成本明細（ap-northeast-1，以月計算）

> 基準：2 個 Worker Node，持續運行 720 小時（30 天）

| AWS 服務 | 規格 | 單價（Tokyo） | 月費用 |
|---------|------|-------------|-------|
| **EKS Control Plane** | 受管控制平面（1 個叢集） | $0.10 / 小時 | **$72.00** |
| **EC2 Worker Nodes** | **2× Spot Instances (Mixed)** | **約 $0.008 / 小時 (估算)** | **$11.52** (原價 $39.17) |
| **NAT Gateway** | 1× Single NAT（hourly + 資料處理費） | $0.062 / 小時 + $0.062/GB | **~$50.00** |
| **EBS（根磁碟）** | 2× 20GB gp3（Each Node） | $0.096 / GB / 月 | **$3.84** |
| **ALB（Load Balancer）** | 1× Application Load Balancer | $0.008 / 小時 + LCU 費用 | **~$6.50** |
| | | **每月合計** | **≈ $144 USD** (省下約 $30+) |

### 💡 換算參考
- **每日費用**：約 $4.80 USD（約 NT$ 155）
- **SPOT 策略價值**：僅僅一個參數的改動，就讓 Worker Node 成本下降了 **70%**。
- **`terraform destroy` 後**：除 EKS 以外的費用歸零，展示完即銷毀是最佳成本控制

> **工程師思維**：Demo 結束後立即執行 `terraform destroy`，將資源存留時間從常駐（$175/月）降至每次展示 2 小時（$0.48 次），這就是 IaC 的財務彈性價值所在。

---

## 三、生產環境成本規模推估

> 情境假設：中型電商，平峰 QPS 約 500，高峰（促銷活動）QPS 約 2,000

### 方案 A：生產基礎版（On-Demand，無優化）

| AWS 服務 | 生產規格 | 月費用推估 |
|---------|---------|----------|
| EKS Control Plane | 1 個叢集 | $72.00 |
| EC2 Worker Nodes | 3× t3.medium（On-Demand） | $117.50 |
| NAT Gateway（HA 雙 AZ） | 2× NAT GW（每 AZ 各一，確保高可用） | $89.28 |
| EBS（根磁碟） | 3× 20GB gp3 | $5.76 |
| EBS（應用資料碟） | 3× 50GB gp3 | $14.40 |
| ALB（含 LCU 流量費） | 1× ALB（含真實流量 LCU 計費） | ~$30.00 |
| 資料傳輸費 | 估算出站流量 100GB/月 | ~$11.00 |
| **每月合計** | | **≈ $340 USD** |

### 方案 B：生產優化版（混合 Spot + Reserved Instances）

| 優化策略 | 節省幅度 | 月費用推估 |
|---------|---------|----------|
| EKS Control Plane | 無折扣（受管服務） | $72.00 |
| 1× t3.medium On-Demand（基礎穩定節點） | 原價 $39.17 | $39.17 |
| 2× t3.medium Spot（可中斷工作節點） | Spot 均價約 70% 折扣 → $0.0163/hr | **$23.47** |
| NAT Gateway（HA 雙 AZ） | 無法優化（按需計費） | $89.28 |
| EBS gp3 磁碟 | 無折扣 | $20.16 |
| ALB | 無折扣 | ~$30.00 |
| 資料傳輸費 | 無折扣 | ~$11.00 |
| **每月合計** | | **≈ $285 USD** |
| **vs. 方案 A 節省** | | **約節省 $55/月（-16%）** |

### 方案 C：進階生產優化版（Reserved + Spot + Karpenter）

| 優化策略 | 說明 | 預期節省 |
|---------|------|---------|
| **1-Year Reserved Instance（穩定 Node）** | 對基礎節點購買 1 年期 RI，可節省約 38% | -$15/月 |
| **Karpenter 替換 Managed Node Group** | 更精準的 bin-packing，減少 Node 閒置資源浪費 | -$20～30/月 |
| **Spot Instance + Interruption Handler** | 90% 工作節點使用 Spot，搭配 `aws-node-termination-handler` | -$50/月 |
| **NAT Gateway 流量優化** | 部分 AWS 服務改走 VPC Endpoint（S3, ECR, SSM），減少 NAT GW 流量費 | -$10/月 |
| **估算優化後月費** | | **≈ $190～210 USD** |

---

## 四、EKS 架構 vs. 傳統 EC2 手動管理的 TCO 比較

> **TCO（Total Cost of Ownership）= 直接費用 + 間接人力成本**

| 比較維度 | 傳統 EC2 手動管理 | AWS EKS + K8S 架構 |
|---------|----------------|-------------------|
| **基礎設施費用** | 同等規格 EC2 費用相近 | 多 EKS Control Plane $72/月 |
| **人力運維成本** | 高：手動擴機、手動重啟、手動發版管理 | 低：HPA 自動擴縮、Self-healing、Canary 自動化 |
| **故障恢復時間（MTTR）** | 10～30 分鐘（需人工介入） | < 30 秒（K8S 自動重建 Pod） |
| **發版風險成本** | 高：全量更新，出問題全站崩潰 | 低：Canary 20% 曝光，問題 < 10 秒回滾 |
| **彈性伸縮效率** | 手動加 EC2 需 5～30 分鐘 | HPA 觸發後 60 秒內 Pod 自動擴充 |
| **一次性建置成本** | 高（手動設定環境，難以重現） | 低（`terraform apply` 一鍵重現） |
| **跨環境複製成本** | 高（每個環境需重新設定） | 幾乎為零（改變數即可重建） |
| **結論** | 適合極小型、靜態流量應用 | **現代電商、高流量應用的必要選擇** |

---

## 五、本專案的成本優化決策解析（架構師思維展示）

### 決策 1：`single_nat_gateway = true`
```hcl
# vpc.tf
enable_nat_gateway   = true
single_nat_gateway   = true   # ← 這裡是關鍵
```
- **成本影響**：NAT Gateway 費用從 $89.28（雙 AZ）→ $44.64（單一），**節省 $44.64/月（50%）**。
- **取捨說明**：單一 NAT GW 是 **單點故障（SPOF）**，若 NAT GW 所在 AZ 發生故障，所有私有子網的出站流量都會中斷。Demo 環境可以接受此風險；生產環境應改用 `one_nat_gateway_per_az = true`。
- **這展現什麼能力**：能量化分析架構決策的財務影響，且清楚知道 Dev 與 Prod 環境的取捨邊界。

### 決策 2：`max_size = 3`（Node Group 上限保護）
```hcl
# eks.tf
eks_managed_node_groups = {
  default = {
    min_size     = 1
    max_size     = 3   # ← 防止無限擴容的保護機制
    desired_size = 2
  }
}
```
- **成本影響**：若 HPA 因 Bug 觸發無限擴容（例如 CPU 指標異常），最多只會建立 3 台 Node，而不是 30 台。
- **財務保護**：3 台 t3.small = 約 $58.75/月 vs. 30 台意外擴容 = 約 $587/月，**一個參數保護了 10 倍的潛在額外支出**。
- **這展現什麼能力**：理解雲端費用的不可預測性，主動設計防護機制，體現 FinOps（雲端財務管理）思維。

### 決策 3：EBS Volume Type 選擇 `gp3`
```hcl
# eks.tf
ebs = {
  volume_size = 20
  volume_type = "gp3"   # ← 不是 gp2
}
```
- **成本影響**：gp3 vs. gp2 同規格（20GB）：gp3 $1.92/月 vs. gp2 $2.30/月，gp3 **便宜 16% 且效能基準更高**（gp3 基準 3,000 IOPS，gp2 只有 100 IOPS Start）。
- **這展現什麼能力**：對 AWS 儲存服務的細節掌握，知道 gp3 是 2021 年後的最佳實踐，不沿用舊型 gp2。

### 決策 4：刻意選擇 `t3.small` 而非 `t3.micro`
```hcl
instance_types = ["t3.small"]   # 2 vCPU, 2GB RAM
```
- **為什麼不用 t3.micro（更便宜）**：t3.micro 只有 1GB RAM，K8S 系統元件（kubelet、CoreDNS、kube-proxy）本身就需要約 400MB，留給應用的記憶體所剩無幾，Pod 會因 OOMKilled（記憶體不足被強制終止）而不斷重啟。
- **這展現什麼能力**：不是以最低價格為優先，而是以「資源足夠且不浪費」為原則做出有根據的規格選擇。

---

## 六、未來可導入的進階成本優化方向

| 優化技術 | 說明 | 預期效益 |
|---------|------|---------|
| **AWS Spot Instances** | 對 Stateless Pod（如 Backend）使用 Spot，Spot 均價比 On-Demand 便宜 60～80% | Node 費用降低最多 70% |
| **Karpenter（自動節點供應）** | 替換 Managed Node Group，依照 Pod 需求動態選擇最便宜的可用機型，改善 Bin-packing 效率 | 減少 20～40% Node 閒置資源 |
| **VPC Endpoints（Gateway / Interface）** | 讓 S3、ECR、SSM 等 AWS 服務的流量走 AWS 骨幹網路，不經過 NAT Gateway，節省資料傳輸費 | NAT Gateway 流量費降低 30～50% |
| **1-Year Reserved Instances** | 對必須常駐的基礎節點購買 1 年期預留，相較 On-Demand 節省約 38% | 穩定節點費用降低 38% |
| **KEDA（基於事件的伸縮）** | 更精準的彈性伸縮，可基於 Queue 長度、Schedule 等非 CPU 指標驅動擴縮，避免資源浪費 | 精準匹配負載，降低閒置成本 |

---

## 七、成本設計能力總結

> 「一個好的雲端架構師，不只是讓系統跑起來，而是讓系統在合理的成本內穩定運行。」

本專案在成本維度展現了三個層次的工程能力：

1. **「當下決策層」**：每一個 Terraform 參數都有成本意涵（NAT GW 數量、Node 規格選擇、磁碟類型、Replica 上限）。
2. **「財務量化層」**：能清楚說明每個架構選擇的月度財務影響與取捨（TCO 分析）。
3. **「演進規劃層」**：知道 Demo 環境與 Production 環境的成本邊界，以及導入 Spot、Karpenter、Reserved 的優先順序與效益。

---

*本報告數據以 AWS 東京區域（ap-northeast-1）2024 年公開定價為基礎，實際費用依流量與使用時長有所差異。*
*參考來源：[AWS Pricing Calculator](https://calculator.aws/) · [EC2 Tokyo Pricing](https://aws.amazon.com/ec2/pricing/on-demand/) · [EKS Pricing](https://aws.amazon.com/eks/pricing/)*

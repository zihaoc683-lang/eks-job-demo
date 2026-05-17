/**
 * # VPC Configuration
 * 
 * 本檔案負責建立 EKS 叢集運行的網路環境 (Virtual Private Cloud)。
 * 採用標準的三層網路架構 (Public/Private Subnets)，確保安全性與高可用性。
 */

# 查詢目前的可用區域 (AZ)
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  # 關鍵設定：跨可用區 (Multi-AZ) 配置
  # 這裡取前兩個 AZ，確保叢集具備高可用性 (High Availability)，當單一機房故障時仍能運作。
  # 為什麼是 2 個而非 3 個：與下方 private_subnets / public_subnets 的數量對齊（各定義了 2 個子網）。
  # 若要擴展至 3 個 AZ，需同步增加子網 CIDR 定義，並評估 NAT Gateway 的成本增加。
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # 私有子網：放置 EKS Worker Nodes 與資料庫，不直接對外開放
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  # 公有子網：放置 Load Balancer 與 NAT Gateway，負責流量進出通訊
  public_subnets = ["10.0.101.0/24", "10.0.102.0/24"]

  # 成本考量：僅部署一個 NAT Gateway 供所有私有子網共用
  # NAT Gateway 讓私有子網的節點可主動對外連網 (例如拉取 Docker Image)，但不對外暴露 IP。
  # 單一 NAT Gateway 的可用性風險：若該 NAT Gateway 所在的 AZ 發生故障，
  # 兩個私有子網的所有節點都將同時失去對外連線能力（無法拉取映像檔、無法呼叫 AWS API）。
  # 生產環境建議將 single_nat_gateway 改為 false，讓每個 AZ 各有獨立的 NAT Gateway，
  # 代價是約多 2 倍的 NAT Gateway 費用（約 $32/月 per gateway）。
  enable_nat_gateway = true
  single_nat_gateway = true

  # 啟用 DNS 解析，這是 EKS 節點加入叢集與服務發現的基礎
  enable_dns_hostnames = true
  enable_dns_support   = true

  # 關鍵標籤：這些 Tags 會引導 K8S AWS Cloud Provider 自動識別子網來建立彈性負載平衡器 (ELB)
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = 1 # 標註此子網可用於建立對外公開的 Load Balancer
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = 1 # 標註此子網可用於建立對內私有的 Load Balancer
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

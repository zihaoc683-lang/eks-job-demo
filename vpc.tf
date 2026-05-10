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

  # 只取前兩個 AZ，以在「節省成本」與「多可用區高可用性」之間取得平衡
  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  
  # 私有子網：放置 EKS Worker Nodes 與資料庫，不直接對外開放
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  
  # 公有子網：放置 Load Balancer 與 NAT Gateway，負責流量進出通訊
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # 成本考量：僅部署一個 NAT Gateway 供所有私有子網共用 (生產環境建議改為每 AZ 一個)
  enable_nat_gateway   = true
  single_nat_gateway   = true

  # 建立資料庫與快取專用子網群組，解決 VPC Mismatch 問題
  create_database_subnet_group    = true
  database_subnets                = ["10.0.151.0/24", "10.0.152.0/24"]
  
  create_elasticache_subnet_group = true
  elasticache_subnets             = ["10.0.161.0/24", "10.0.162.0/24"]

  # 啟用 DNS 解析，這是 EKS 節點加入叢集與服務發現的基礎
  enable_dns_hostnames = true
  enable_dns_support   = true

  # 關鍵標籤：這些 Tags 會引導 K8S AWS Cloud Provider 自動識別子網來建立彈性負載平衡器 (ELB)
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = 1          # 標註此子網可用於建立對外公開的 Load Balancer
    "kubernetes.io/cluster/${var.cluster_name}"   = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = 1          # 標註此子網可用於建立對內私有的 Load Balancer
    "kubernetes.io/cluster/${var.cluster_name}"   = "shared"
  }
}


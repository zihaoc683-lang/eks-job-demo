/**
 * # EKS Cluster Configuration
 * 
 * 本檔案定義了 Amazon EKS 叢集的核心架構。
 * 包含控制平面 (Control Plane)、受管節點組 (Managed Node Groups) 以及基礎套件 (Add-ons)。
 */

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name = var.cluster_name
  # EKS K8S 叢集版本：鎖定 1.31 這是目前 AWS 比較通用的現代版本
  cluster_version = "1.31"

  # 網路配置：將 EKS 部署於 VPC 的私有子網中，且自動繼承跨可用區 (Multi-AZ) 的特性
  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  # 允許從外部存取 EKS API Endpoint (建議生產環境限制來源 IP)
  cluster_endpoint_public_access = true

  # 為了簡化本地測試，自動加權限給執行 Terraform 的 IAM User/Role
  enable_cluster_creator_admin_permissions = true

  # 解決 LoadBalancer Sync 失敗：明確加入叢集權限政策
  iam_role_additional_policies = {
    AmazonEKSClusterPolicy         = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    AmazonEKSVPCResourceController = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  }

  # 控制 K8S 原生套件 (Add-ons)
  cluster_addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni    = {}
    # AWS EBS CSI 驅動程式：讓 K8S 能動態建立與掛載 AWS EBS 磁碟 (支援 StatefulSet 測試)
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa_role.iam_role_arn
    }
  }

  # 實體機器池設定 (Managed Node Groups)
  eks_managed_node_groups = {
    default = {
      # 成本核心優化：使用 SPOT 實例 (Spot Instances)
      # 為什麼：Spot 實例利用 AWS 閒置資源，價格比 On-Demand 便宜 60~90%。
      # 雖然有被收回的風險，但對於 Demo 環境或 Stateless 的 K8S 應用是最佳的成本策略。
      capacity_type = "SPOT"

      # 機器規模限制：最多 3 台，這能避免測試時產生非預期的巨大帳單支出
      min_size     = 1
      max_size     = 5
      # 預設 3 台。注意：若安裝了 Prometheus 等大量組件，t3.small 的 ENI 限制 (11 pod/node) 
      # 可能會導致 Pod 卡在 Pending，此時請將此數值調升至 4 或 5。
      desired_size = 4

      # 使用 t3.small (2 vCPU, 2GB RAM)：足夠運行我們的電商 Demo 應用
      instance_types = ["t3.small", "t3.medium"] # 增加備選機型提高 Spot 獲得率

      # 自定義根磁碟大小與類型 (gp3 提供更穩定的硬體效能比)
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size           = 20
            volume_type           = "gp3"
            delete_on_termination = true
          }
        }
      }
    }
  }

  node_security_group_additional_rules = {
    ingress_allow_access_from_anywhere = {
      description = "Allow access from anywhere"
      protocol    = "tcp"
      from_port   = 30000
      to_port     = 32767
      type        = "ingress"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }


  tags = {
    Environment = "demo"
    Project     = "ecommerce"
  }

  # ==========================================
  # 安全機制：防止刪除死結 (Stability Optimization)
  # ==========================================
  # 確保在刪除 VPC 之前，EKS 已經徹底關閉並等待了 ENI 的回收時間
  depends_on = [
    time_sleep.wait_for_eni_cleanup,
    module.vpc
  ]
}

# IAM Role for Service Accounts (IRSA)：讓 EBS CSI Driver 有權限操作 AWS API
module "ebs_csi_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.30"

  role_name             = "${var.cluster_name}-ebs-csi"
  attach_ebs_csi_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}


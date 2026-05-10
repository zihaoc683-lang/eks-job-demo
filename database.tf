# =========================================================================
# 企業級資料備援：AWS RDS (MySQL) & ElastiCache (Redis)
# =========================================================================
# 說明：針對職缺中強調的「資料庫維護 (MySQL/Redis)」，我們透過 Terraform 實作。
# 在生產環境中，我們不會將資料存放在 K8s Pod 內，而是推向高效能、具備自動備份的 RDS。
# =========================================================================

# 1. 安全群組：僅允許 EKS 節點連線至資料庫
resource "aws_security_group" "db_sg" {
  name        = "ecommerce-db-sg"
  description = "Allow EKS to MySQL"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }
}

# 2. RDS MySQL 實例
resource "aws_db_instance" "mysql" {
  identifier           = "ecommerce-prod-db"
  allocated_storage    = 20
  storage_type         = "gp3"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro" # 測試環境使用微型，面試時說明生產環境可用 db.m5.xlarge
  db_name              = "ecommerce"
  username             = "admin"
  password             = "Password123" # 展示用，應結合 Secret Manager
  parameter_group_name = "default.mysql8.0"
  skip_final_snapshot  = true
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = module.vpc.database_subnet_group_name

  # 面試加分點：自動備份與多可用區 (Multi-AZ)
  backup_retention_period = 7
  multi_az               = false # 節省 Demo 成本，面試說明生產會開 Multi-AZ

  depends_on = [module.vpc, aws_security_group.db_sg]
}

# 3. Redis 快取實例 (AWS ElastiCache)
# 用於 Session 存儲或熱點資料加速，對應網訊電通與 TVBS 的需求
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "ecommerce-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = module.vpc.elasticache_subnet_group_name
  security_group_ids   = [aws_security_group.db_sg.id]

  depends_on = [module.vpc, aws_security_group.db_sg]
}

/**
 * # Variables Configuration
 * 
 * 本檔案定義了此 Terraform 專案所需的輸入變數。
 * 透過參數化設定，我們可以輕鬆地切換佈署區域、修改叢集參數而不需要變更主邏輯代碼。
 */

variable "region" {
  description = "AWS 資源部署的區域 (例如 ap-northeast-1 代表東京)"
  type        = string
  default     = "ap-northeast-1"
}

variable "cluster_name" {
  description = "EKS 叢集的名稱，這也會作為 VPC 與相關資源的命名基底"
  type        = string
  default     = "ecommerce-eks-demo"
}

variable "vpc_cidr" {
  description = "VPC 的網段定義 (CIDR Block)，影響可分配的 IP 數量"
  type        = string
  default     = "10.0.0.0/16"
}


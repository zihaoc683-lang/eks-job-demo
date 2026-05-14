/**
 * # Outputs Configuration
 * 
 * 本檔案定義了部署完成後的輸出資訊。
 * 這些數值可以用於後續的腳本自動化，或手動設定開發環境。
 */

# EKS 叢集名稱
output "cluster_name" {
  description = "EKS 叢集的名稱"
  value       = module.eks.cluster_name
}

# EKS API 端點
output "cluster_endpoint" {
  description = "EKS 控制平面的 API 存取點"
  value       = module.eks.cluster_endpoint
}

# 快速設定指令
# 執行此輸出指令即可自動為本地端配置 kubectl 存取權限
# 用法：terraform output -raw configure_kubectl | bash
output "configure_kubectl" {
  description = "設定本地 kubectl 以存取此叢集的指令"
  value       = "aws eks --region ${var.region} update-kubeconfig --name ${module.eks.cluster_name}"
}


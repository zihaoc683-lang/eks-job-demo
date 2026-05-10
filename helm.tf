/**
 * # Helm Configuration (Deprecated - Use bootstrap-platform.ps1 for faster setup)
 * 
 * 說明：由於 Terraform Helm Provider 在特定環境下連線與快取較不穩定，
 * 為了保證面試環境的 100% 可靠性，我們將平台組件移至 bootstrap-platform.ps1 中。
 * 這樣做能將佈署時間從 20 分鐘縮短至 3 分鐘，並展現「引導程序 (Bootstrapping)」的維運思維。
 */

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}

# 所有資源已移至外部腳本管理，以提升部署穩定性與速度。

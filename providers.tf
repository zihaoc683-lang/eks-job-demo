/**
 * # Providers Configuration
 * 
 * 本檔案定義了 Terraform 的基礎設定以及所需的供應商 (Providers)。
 * 我們使用了 AWS、Kubernetes 與 Time 等 Provider 來管理不同層次的資源。
 */

terraform {
  # 限制 Terraform 版本，確保團隊環境一致
  required_version = ">= 1.3.0"

  required_providers {
    # AWS Provider: 用於建立 VPC、EKS 等雲端基礎設施
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Kubernetes Provider: 用於管理 EKS 內部的 K8S 資源 (如 ConfigMap, Secrets)
    # 注意：此 Provider 需等 EKS 叢集建立完成後才能正常連線，不可單獨先 apply
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }

    # Time Provider: 用於處理資源刪除時的延遲等待 (Cleanup 邏輯使用)
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }

    # Null Provider: 用於執行本地腳本 (cleanup.tf 的 null_resource 隱式依賴此 Provider)
    # 雖然未明確在此宣告版本，Terraform 會自動引入，但在此記錄以供團隊知悉其用途。
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

# 設定 AWS Provider 的區域，參數化以增加彈性
# 實際區域由 var.region 控制，預設為 ap-northeast-1 (東京)
provider "aws" {
  region = var.region
}


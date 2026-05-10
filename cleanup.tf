/**
 * # Cleanup Configuration
 * 
 * 架構思維：解決 EKS 資源刪除死結 (DependencyViolation)
 * 
 * 1. 外部依賴：K8S 生成的 LoadBalancer (ELB) 不受 Terraform 直接管理。
 * 2. 資源鎖定：若不先刪除 ELB，它會鎖死 Subnet 內的網路介面 (ENI)，導致 VPC 無法刪除。
 * 3. 自動對策：在 EKS 消失前強制執行清場腳本，並延遲 60s 給 AWS 背景回收資源。
 */

# 在刪除 EKS 之前，先清理 K8S 內部的 Resources
resource "null_resource" "k8s_cleanup" {
  provisioner "local-exec" {
    when    = destroy
    command = "kubectl delete -f k8s/ -R --ignore-not-found || (exit 0)"
  }

  # 確保此動作在 EKS 叢集還是活著的時候執行
  depends_on = [module.eks]
}

# 延遲等待：防止刪除死結 (Deadlock Prevention)
# 架構邏輯：
# 1. 為了防止 VPC 刪除時發生 DependencyViolation (因為 EKS 殘留的 ENI 未釋放)。
# 2. 我們讓此資源依賴於 VPC，並讓 EKS 依賴於此資源。
# 3. 刪除順序將變為：EKS 叢集 -> 本資源 (等待 60s) -> VPC。
resource "time_sleep" "wait_for_eni_cleanup" {
  # 建立時不需要等待
  create_duration = "1s"

  # 僅在執行 terraform destroy 時觸發等待 60 秒
  # 這段時間是給 AWS 背景程序回收網路介面 (ENI) 與負載平衡器 (ELB) 的緩衝期
  destroy_duration = "60s"

  depends_on = [module.vpc]
}


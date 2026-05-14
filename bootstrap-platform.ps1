# =========================================================================
# EKS Platform Bootstrap Script (Compatibility Version)
#
# 用途：一鍵將所有平台層套件部署到 EKS 叢集。
# 執行前提：
#   1. 已完成 terraform apply，EKS 叢集與 VPC 均已就緒。
#   2. 本機已安裝 AWS CLI、kubectl，並設定好有效的 AWS 認證 (aws configure)。
#
# 安裝順序說明：
#   順序有意義，不可任意調換。
#   Metrics Server 必須最先就緒，因為 HPA (水平自動擴縮) 依賴它的 API。
#   Argo Rollouts 需在應用部署前存在，否則 Rollout 資源會找不到 Controller 而卡住。
#   Kyverno 與 Trivy 屬於治理/安全層，需在工作負載上線前掃描與攔截。
#   Argo CD 最後安裝，確保上方的 CRD 都已註冊完成，避免 Sync 時找不到資源定義。
# =========================================================================

# --------------------------------------------------
# 前置：更新本地 kubeconfig
# 讓 kubectl 知道如何連線到指定的 EKS 叢集 API Server。
# 若已執行過 terraform output configure_kubectl 則效果相同。
# --------------------------------------------------
Write-Host "Updating EKS Kubeconfig..." -ForegroundColor Cyan
aws eks --region ap-northeast-1 update-kubeconfig --name ecommerce-eks-demo

# --------------------------------------------------
# 步驟 1：Metrics Server
# 功能：收集叢集內所有 Node 與 Pod 的 CPU/Memory 使用量，
#       並透過 Kubernetes Metrics API 對外提供數據。
# 必要性：kubectl top、HPA (HorizontalPodAutoscaler) 均依賴此 API，
#         未安裝時 HPA 無法正常運作，Pod 也無法自動擴縮。
# --------------------------------------------------
Write-Host "1. Installing Metrics Server..." -ForegroundColor Yellow
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# --------------------------------------------------
# 步驟 2：Argo Rollouts
# 功能：擴充 K8S 原生的 Deployment，支援 Blue/Green 與 Canary 等進階發布策略。
# 必要性：應用層的 Rollout 資源必須有對應的 Controller 才能被執行，
#         需在部署應用前安裝，否則 Rollout 物件會永久卡在 Pending 狀態。
# --dry-run=client -o yaml | kubectl apply：冪等做法，避免 namespace 已存在時報錯。
# --------------------------------------------------
Write-Host "2. Installing Argo Rollouts..." -ForegroundColor Yellow
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# --------------------------------------------------
# 步驟 3：Kyverno (Policy Engine)
# 功能：K8S 原生的政策引擎，可在資源建立/更新時進行驗證、變更與產生。
#       例如：強制所有 Pod 必須設定 resource limits、禁止使用 latest tag。
# --server-side --force-conflicts：Kyverno 的 CRD 較大，超過 kubectl 預設的
#   annotation 大小限制，必須改用 Server-Side Apply 才能成功套用。
# --------------------------------------------------
Write-Host "3. Installing Kyverno..." -ForegroundColor Yellow
kubectl apply --server-side --force-conflicts -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml

# --------------------------------------------------
# 步驟 4：Trivy Operator (Container Security Scanner)
# 功能：持續掃描叢集內所有 Pod 使用的容器映像檔，偵測已知 CVE 漏洞，
#       並將報告以 K8S CRD (VulnerabilityReport) 形式存回叢集供查詢。
# --server-side --force-conflicts：同 Kyverno，CRD 較大須使用 Server-Side Apply。
# --------------------------------------------------
Write-Host "4. Installing Trivy Operator..." -ForegroundColor Yellow
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/aquasecurity/trivy-operator/main/deploy/static/trivy-operator.yaml

# --------------------------------------------------
# 步驟 5：Argo CD (GitOps Continuous Delivery)
# 功能：監控 Git Repository，自動將 repo 中宣告的 K8S 資源狀態同步到叢集，
#       實現 GitOps 工作流程 (Git 即為唯一事實來源)。
# 最後安裝的原因：Argo CD 在 Sync 時會嘗試識別叢集內所有 CRD，
#                 若 Argo Rollouts / Kyverno 的 CRD 尚未就緒，Sync 會報錯。
# --dry-run=client -o yaml | kubectl apply：冪等建立 namespace，避免重複執行時出錯。
# --------------------------------------------------
Write-Host "5. Installing Argo CD..." -ForegroundColor Yellow
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# --------------------------------------------------
# 步驟 6：EBS StorageClass
# 功能：套用自訂的 StorageClass，將 EBS gp3 設定為叢集的預設 Storage Class。
#       後續 StatefulSet (如 Prometheus、資料庫) 的 PVC 將自動使用此 Class 動態建立 EBS Volume。
# 前提：eks.tf 中已透過 IRSA 為 EBS CSI Driver 授予 AWS EBS 操作權限。
# --------------------------------------------------
Write-Host "6. Deploying EBS Storage..." -ForegroundColor Yellow
kubectl apply -f k8s/01-storage.yaml

# --------------------------------------------------
# 完成提示
# --------------------------------------------------
Write-Host "Done! All components deployed successfully." -ForegroundColor Green
Write-Host "Please follow docs/02-demo-guide.md to start your demo." -ForegroundColor Green
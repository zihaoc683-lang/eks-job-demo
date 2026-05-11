# =========================================================================
# EKS Platform Bootstrap Script (Compatibility Version)
# =========================================================================

Write-Host "Updating EKS Kubeconfig..." -ForegroundColor Cyan
aws eks --region ap-northeast-1 update-kubeconfig --name ecommerce-eks-demo

Write-Host "1. Installing Metrics Server..." -ForegroundColor Yellow
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

Write-Host "2. Installing Argo Rollouts..." -ForegroundColor Yellow
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

Write-Host "3. Installing Kyverno..." -ForegroundColor Yellow
kubectl apply --server-side --force-conflicts -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml

Write-Host "4. Installing Trivy Operator..." -ForegroundColor Yellow
kubectl apply --server-side --force-conflicts -f https://raw.githubusercontent.com/aquasecurity/trivy-operator/main/deploy/static/trivy-operator.yaml

Write-Host "5. Installing Argo CD..." -ForegroundColor Yellow
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply --server-side --force-conflicts -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

Write-Host "5. Deploying EBS Storage..." -ForegroundColor Yellow
kubectl apply -f k8s/01-storage.yaml

Write-Host "Done! All components deployed successfully." -ForegroundColor Green
Write-Host "Please follow docs/02-demo-guide.md to start your demo." -ForegroundColor Green

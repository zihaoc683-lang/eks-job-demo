# =========================================================================
# SRE 診斷工具：EKS 節點參數審計 (Node Audit)
# =========================================================================
# 功能：檢查 EKS Worker Node 目前的 net.core.somaxconn 數值
# 用途：演示「審計 (Audit)」階段，確認節點是否符合安全基準
# 對應 Ansible Task：Task 4（4. 優化核心連線參數）的審計前置動作
#
# 映像白名單警告：
#   nicolaka/netshoot 不在 Kyverno 映像白名單內
#   若場景三的 Policy 仍存在，此腳本會被 Admission Webhook 攔截
#   解決方式：kubectl delete clusterpolicy disallow-privileged-containers
# =========================================================================

Write-Host "Checking current net.core.somaxconn on EKS node..." -ForegroundColor Cyan

kubectl delete pod node-audit-tool --ignore-not-found > $null 2>&1

@"
apiVersion: v1
kind: Pod
metadata:
  name: node-audit-tool
spec:
  hostPID: true
  restartPolicy: Never
  containers:
  - name: node-audit-tool
    image: nicolaka/netshoot
    securityContext:
      privileged: true
    command: ["sh", "-c", "echo '>>> Current Node Setting:' && nsenter -t 1 -m -u -n -i sysctl net.core.somaxconn"]
"@ | kubectl apply -f -

Start-Sleep -Seconds 5
kubectl logs node-audit-tool
kubectl delete pod node-audit-tool --ignore-not-found
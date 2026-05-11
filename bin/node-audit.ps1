# =========================================================================
# SRE 診斷工具：EKS 節點參數審計 (Node Audit)
# =========================================================================

Write-Host "Checking current 'net.core.somaxconn' on EKS node..." -ForegroundColor Cyan

# 1. 確保環境乾淨
kubectl delete pod node-audit-tool --ignore-not-found > $null 2>&1
Start-Sleep -Seconds 1

# 2. 執行審計 (使用與 node-reset 相同的轉義語法)
kubectl run node-audit-tool --rm -i --tty --image=nicolaka/netshoot --restart=Never --privileged --overrides='{\"spec\":{\"hostPID\":true}}' -- sh -c "echo '>>> Current Node Setting:'; nsenter -t 1 -m -u -n -i sysctl net.core.somaxconn"

# =========================================================================
# SRE 修復工具：EKS 節點安全加固 (Node Remediation)
# =========================================================================
# 功能：將 net.core.somaxconn 提升至 1024，優化高併發流量處理能力。
# 技術：模擬 Ansible 行為，直接針對 Host OS 進行即時配置。
# =========================================================================

Write-Host "Applying hardening: setting 'net.core.somaxconn' to 1024..." -ForegroundColor Yellow

# 清除舊的殘留 Pod
kubectl delete pod node-fix --ignore-not-found > $null 2>&1

# 使用 netshoot 並確保不重啟
kubectl run node-fix --rm -i --tty --image=nicolaka/netshoot --restart=Never --privileged --overrides='{\"spec\":{\"hostPID\":true}}' -- sh -c "nsenter -t 1 -m -u -n -i sysctl -w net.core.somaxconn=1024"

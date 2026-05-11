# =========================================================================
# SRE 診斷工具：EKS 節點參數審計 (Node Audit)
# =========================================================================
# 功能：檢查 EKS 工作節點 (EC2) 上的 net.core.somaxconn 內核參數。
# 技術：透過特權容器與 nsenter 切入 Host 命名空間，實現無 SSH 管理。
# =========================================================================

Write-Host "Checking current 'net.core.somaxconn' on EKS node..." -ForegroundColor Cyan

# 清除舊的殘留 Pod 確保名稱不衝突
kubectl delete pod node-audit --ignore-not-found > $null 2>&1

# 使用 netshoot 映像檔，因其內建了 nsenter 等作業系統層級調錯工具
kubectl run node-audit --rm -i --tty --image=nicolaka/netshoot --restart=Never --privileged --overrides='{\"spec\":{\"hostPID\":true}}' -- sh -c "nsenter -t 1 -m -u -n -i sysctl net.core.somaxconn"

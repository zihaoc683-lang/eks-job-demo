# =========================================================================
# SRE 演示工具：情境重置 (Scenario Reset)
# =========================================================================
# 功能：將 somaxconn 還原至 128，以便重新演示審計與修復過程。
# 技術：僅用於 Demo 情境，將系統推回「不合規」狀態。
# =========================================================================

Write-Host "Resetting 'net.core.somaxconn' to 128 (Linux default) for demo purposes..." -ForegroundColor Gray

# 清除舊的殘留 Pod
kubectl delete pod node-reset --ignore-not-found > $null 2>&1

# 使用 netshoot 進行重置動作
kubectl run node-reset --rm -i --tty --image=nicolaka/netshoot --restart=Never --privileged --overrides='{\"spec\":{\"hostPID\":true}}' -- sh -c "nsenter -t 1 -m -u -n -i sysctl -w net.core.somaxconn=128"

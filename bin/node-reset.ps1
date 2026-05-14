# =========================================================================
# SRE 演示工具：情境重置 (Scenario Reset)
# =========================================================================
# 功能：將 net.core.somaxconn 還原至 128，以便重新演示審計與修復過程
# ⚠️ 警告：本腳本僅用於 Demo 情境，絕對不可在生產環境執行
#          128 會導致高併發下連線被 Drop
#
# 128 的來源：Linux 核心長期維護的預設值（自 kernel 2.x 時代沿用至今）
#             設計當時的網路流量遠低於現代微服務架構，已不符合生產需求
#
# 映像白名單警告：
#   nicolaka/netshoot 不在 Kyverno 映像白名單內
#   若場景三的 Policy 仍存在，此腳本會被 Admission Webhook 攔截
#   解決方式：kubectl delete clusterpolicy disallow-privileged-containers
# =========================================================================

Write-Host "[DEMO ONLY] Resetting net.core.somaxconn to 128..." -ForegroundColor Red
Write-Host "⚠️  This setting is intentionally non-compliant. Do NOT run in production." -ForegroundColor Red

kubectl delete pod node-reset --ignore-not-found > $null 2>&1

@"
apiVersion: v1
kind: Pod
metadata:
  name: node-reset
spec:
  hostPID: true
  restartPolicy: Never
  containers:
  - name: node-reset
    image: nicolaka/netshoot
    securityContext:
      privileged: true
    command: ["sh", "-c", "nsenter -t 1 -m -u -n -i sysctl -w net.core.somaxconn=128 && echo Done"]
"@ | kubectl apply -f -

Start-Sleep -Seconds 5
kubectl logs node-reset
kubectl delete pod node-reset --ignore-not-found
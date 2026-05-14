# =========================================================================
# SRE 修復工具：EKS 節點安全加固 (Node Remediation)
# =========================================================================
# 功能：將 net.core.somaxconn 提升至 1024，優化高併發流量處理能力
# 對應 Ansible Task：Task 4（4. 優化核心連線參數）
#
# 與 Ansible 的對應關係：
#   Ansible：sysctl module → name: net.core.somaxconn, value: '1024', reload: yes
#   本腳本：nsenter → sysctl -w net.core.somaxconn=1024
#   差異：Ansible 會同時寫入 /etc/sysctl.conf 確保重開機後持久生效
#         本腳本只做即時修改，重開機後還原，適合 Demo 展示
#
# 映像白名單警告：
#   nicolaka/netshoot 不在 Kyverno 映像白名單內
#   若場景三的 Policy 仍存在，此腳本會被 Admission Webhook 攔截
#   解決方式：kubectl delete clusterpolicy disallow-privileged-containers
# =========================================================================

Write-Host "Applying hardening: setting net.core.somaxconn to 1024..." -ForegroundColor Yellow

kubectl delete pod node-fix --ignore-not-found > $null 2>&1

@"
apiVersion: v1
kind: Pod
metadata:
  name: node-fix
spec:
  hostPID: true
  restartPolicy: Never
  containers:
  - name: node-fix
    image: nicolaka/netshoot
    securityContext:
      privileged: true
    command: ["sh", "-c", "nsenter -t 1 -m -u -n -i sysctl -w net.core.somaxconn=1024 && echo Done"]
"@ | kubectl apply -f -

Start-Sleep -Seconds 5
kubectl logs node-fix
kubectl delete pod node-fix --ignore-not-found
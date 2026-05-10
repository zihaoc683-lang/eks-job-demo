param (
    [Parameter(Mandatory=$true)]
    [string]$PlaybookPath
)

if (-Not (Test-Path $PlaybookPath)) {
    Write-Host "Cannot find file: $PlaybookPath" -ForegroundColor Red
    exit 1
}

Write-Host "Starting K8s container to run Ansible syntax check..." -ForegroundColor Cyan

kubectl delete configmap ansible-playbook --ignore-not-found > $null 2>&1
kubectl create configmap ansible-playbook --from-file=$PlaybookPath > $null 2>&1

$podYaml = @"
apiVersion: v1
kind: Pod
metadata:
  name: ansible-demo
spec:
  restartPolicy: Never
  containers:
  - name: ansible
    image: cytopia/ansible
    command: ["ansible-playbook", "/playbook/$([System.IO.Path]::GetFileName($PlaybookPath))", "--syntax-check"]
    volumeMounts:
    - name: pb
      mountPath: /playbook
  volumes:
  - name: pb
    configMap:
      name: ansible-playbook
"@

kubectl delete pod ansible-demo --ignore-not-found > $null 2>&1
$podYaml | kubectl apply -f - > $null 2>&1

Write-Host "Waiting for container execution (about 10~20s)..." -ForegroundColor Yellow

$status = ""
while ($status -ne "Succeeded" -and $status -ne "Failed") {
    Start-Sleep -Seconds 2
    $status = (kubectl get pod ansible-demo -o jsonpath='{.status.phase}')
}

Write-Host "
--- Ansible Result ---" -ForegroundColor Green
kubectl logs ansible-demo

kubectl delete pod ansible-demo --ignore-not-found > $null 2>&1
kubectl delete configmap ansible-playbook --ignore-not-found > $null 2>&1
Write-Host "Cleanup done." -ForegroundColor DarkGray
# 🛠️ Ansible EKS 節點維運與安全加固執行指南 (Ansible Runbook)

本說明文件詳細記載了如何透過 **Ansible** 管理與優化 EKS Worker Nodes。專案中提供了完整的 Playbook 劇本與 Inventory 主機清單，為生產環境的高可用與零信任維運奠定基礎。

---

## 📂 核心檔案架構

* **[node-hardening.yml](file:///c:/Users/kilok/Desktop/緯育/eks-project/day5-job-demo/ansible/node-hardening.yml)**：系統加固 Playbook，定義了 OS 安全漏洞修補、核心參數優化 (somaxconn)、時區同步及 SSM 代理配置。
* **[hosts.ini](file:///c:/Users/kilok/Desktop/緯育/eks-project/day5-job-demo/ansible/hosts.ini)**：主機清單 (Inventory) 範本，提供傳統 SSH 與現代化 AWS SSM Session Manager 隧道穿透兩種連線模式。

---

## ⚠️ 演示特別說明 (Demo Note)
本專案中的 `ansible/hosts.ini` 所填寫之 Private IP (如 `10.0.1.15`) 均為**模擬佔位符 (Placeholders)**。
在本地 Demo 演示現場，為了保證秒級展示的流暢度與穩定性，我們使用 `bin/node-fix.ps1` 模擬此 Ansible 劇本的實施成果。

---

## 🛠️ 實務運維操作指令 (SRE Runbook)

在真實的 AWS 生產環境中，SRE 與 DevOps 工程師會透過以下標準指令來操作此架構：

### 1. 節點連線測試 (Connection Ping Test)
在正式部署任何變更前，一律先使用 Ansible Ad-hoc 命令測試與節點的通訊與憑證：
```bash
ansible eks_nodes -i ansible/hosts.ini -m ping
```
* **預期結果**：回傳該節點的 `"ping": "pong"`，狀態顯示為綠色 `SUCCESS`。

### 2. 劇本安全預檢 (Dry-Run / Check Mode)
在不對節點進行任何實體修改的前提下，模擬執行劇本，檢查語法與預期變更：
```bash
ansible-playbook -i ansible/hosts.ini ansible/node-hardening.yml --check
```
* **目的**：確認哪些配置會被修改 (Changed) 或是符合預期狀態 (Ok)，確保變更的安全性。

### 3. 正式套用安全加固與優化 (Run Playbook)
正式執行完整劇本，將所有 EKS 節點的作業系統參數調整至「最終合規狀態」：
```bash
ansible-playbook -i ansible/hosts.ini ansible/node-hardening.yml
```
* **執行任務包括**：
  1. 更新系統全部套件，消除 OS 層級 CVE 漏洞。
  2. 安裝核心排障工具組 (`htop`, `telnet`, `tcpdump`, `jq`, `tmux`)。
  3. 統一時區為 `Asia/Taipei`（滿足 Log Correlation 的日誌合規審計）。
  4. 修改 `/etc/sysctl.conf` 設定 `net.core.somaxconn = 1024`，高併發連線防丟包優化。
  5. 啟用並設定 `amazon-ssm-agent` 服務自動開機啟動。

### 4. 臨時指令派送 (Ad-hoc Diagnostics)
若遇緊急事故，需一次性在所有 EKS 節點上查詢硬體狀態，可直接下達 Ad-hoc 命令：
```bash
# 一口氣查詢所有 EKS 節點的硬碟空間
ansible eks_nodes -i ansible/hosts.ini -m shell -a "df -h"

# 檢查所有節點當前 TCP 隊列設定值
ansible eks_nodes -i ansible/hosts.ini -m shell -a "sysctl net.core.somaxconn"
```

### 5. 局部特定標籤執行 (Tag Filtering)
若臨時有安全緊急通報 (Security Advisory)，只想執行 DNF 安全更新：
```bash
ansible-playbook -i ansible/hosts.ini ansible/node-hardening.yml --tags security
```

---

## 🔒 零信任架構：AWS SSM Session Manager 隧道連線
為了符合金融與企業高規安全審計，本專案在 `hosts.ini` 中提供了 **SSM 穿透配置模式**：
* **優勢**：節點**完全不需要開放 Port 22**，外部完全無法掃描 SSH Port。
* **原理**：透過將 SSH 流量包裝進 AWS CLI 的 ssm 通道 (`aws ssm start-session`)，所有連線皆透過 IAM 授權，並在 AWS CloudTrail 留存完整審計日誌。
* **hosts.ini 配置範例**：
  ```ini
  [eks_nodes_ssm]
  eks-node-az1a-1 ansible_host=i-0123456789abcdef0  # 使用 EC2 實例 ID
  
  [eks_nodes_ssm:vars]
  ansible_user=ec2-user
  ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p"'
  ```

---

## 💡 面試答疑亮點 (Interview Q&A Highlights)

* **Q：在 EKS 這種自動擴縮 (Auto Scaling) 的環境下，Node IP 一直變，如何維護這個 hosts.ini？**
  * **A (SRE 標準回答)**：「在生產環境中，我們不會手動維護靜態的 `hosts.ini`。我們會啟用 **Ansible AWS EC2 Dynamic Inventory** 插件 (`aws_ec2.yml`)。執行時，Ansible 會自動調用 AWS API 查詢具有指定標籤（例如 `kubernetes.io/cluster/ecommerce-eks-demo`）的所有執行中節點，動態生成主機清單，保證與雲端狀態完美同步。」

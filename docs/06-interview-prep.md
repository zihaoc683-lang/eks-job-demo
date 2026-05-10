# 全球人壽 (企業架構處) DevOps/SRE 終極面試攻防戰指南

這份文件為您針對 **「全球人壽保險 - 企業架構處 (Enterprise Architecture)」** 的 Kubernetes DevOps 工程師職缺量身打造。
保險業 (尤其是壽險) 有其獨特的極端要求：**絕對的合規性 (法遵/個資)**、**舊有系統 (Legacy System) 整合**、以及**不能有一絲差錯的高可用性 (BCP/DR)**。

以下針對該職缺，為您預測並羅列出**「最尖銳、最地獄級」**的面試題，並按「尖銳程度 (難度)」由高至低排序，附上 SRE 高級主管視角的破局思維！

---

## 🔥 第一級別：企業架構與法規合規 (地獄級尖銳 - 最考驗眼界)

身處「企業架構處」，面對的不只是單一專案，而是全公司的技術藍圖。

### 🚨 尖銳題 1：「保險業資料涵蓋海量且高度敏感的個資 (PII)。你的 EKS 叢集如何管理機密資料 (Secrets)？如果你說用 K8s Native Secrets，那只是 Base64 編碼，這絕對無法通過我們金管會稽核。你要怎麼解決？」
* **面試官在想什麼**：你在架構圖畫了很高大上的東西，但你究竟懂不懂金融業對密碼/憑證的嚴格合規要求？
* **破局應答思維**：
  > 「對於金融業，原生的 K8s Secret 絕對不合格。我的解決方案有兩種層次：
  > 1. **結合雲端原生的 External Secrets Operator (ESO)**：我會將所有資料庫密碼集中存放在 AWS Secrets Manager 或 HashiCorp Vault。K8s 內部不留存真正的明文 YAML，而是透過 ESO 動態且短暫地同步進來。
  > 2. **最嚴格的 IRSA 與 IAM 控管**：就算有了密碼，誰能讀？我會嚴格配置 IAM Roles for Service Accounts (IRSA)，確保只有『真正需要連線資料庫的那個特定 Pod』具有權限讀取該密碼。此外，必須關閉所有 `kubectl exec` 進入容器的權限，防止內部人員竊取憑證。」

### 🚨 尖銳題 2：「我們壽險業不可能全上公有雲，一定還有地端的 AS/400 大型主機。當 AWS EKS 上的微服務，必須跨網段呼叫地端的核心系統時，在 Telemetry 監控與 API 超時重試上，你的企業級架構思維是什麼？」
* **面試官在想什麼**：你有沒有混合雲 (Hybrid Cloud) 的思維？還是你只懂純 AWS 的美好世界？
* **破局應答思維**：
  > 「混合雲面臨的最大痛點是『不可靠的網路延遲』。
  > 1. **在架構層（重試與斷路器）**：我不會讓基礎網路連線問題拖垮整個系統。我會引入 Service Mesh (如 Istio) 或至少在 AP 端實作斷路器 (Circuit Breaker)。當呼叫地端超時超過三次，直接熔斷，不要傻傻等待導致 AWS 端的 Thread Pool 耗盡。
  > 2. **在 Telemetry (Observability) 層**：必須推動 W3C Trace Context 的分散式追蹤 (Distributed Tracing)。這樣當一張保單出現延遲時，我們從 Grafana Tempo/Jaeger 上能一眼看出，究竟是 EKS 處理台慢了，還是卡在 AWS Direct Connect 的跨雲網路，或者是地端資料庫鎖死了。」

---

## ⚡ 第二級別：災難復原與 SRE 溝通橋樑 (骨灰級難度 - 考驗決策與抗壓)

### 🚨 尖銳題 3：「你說你懂 SRE 且有 GitOps 經驗。如果今天某個維運菜鳥下錯指令，把 Production Namespace 整個刪除了，或者是 AWS 東京區域斷線。透過你的把關機制，你需要多少時間 (RTO) 才能讓系統完全恢復？」
* **面試官在想什麼**：災難演練 (Disaster Recovery)。你口中的 IaC 和 CI/CD 在大災難來臨時，堪不堪用？
* **破局應答思維**：
  > 「在我的設計中，系統能做到『雙層宣告式還原』，我的 RTO 目標是 30 分鐘內。
  > 1. **基礎設施層 (Terraform)**：所有 VPC、EKS、NodeGroup 都在 `eks.tf` 裡。只要一行 `terraform apply` 就能在另一個區域 (如 AWS 大阪) 重新把基礎设施拉起。
  > 2. **應用服務層 (GitOps / ArgoCD)**：因為我導入了 GitOps，K8s 叢集裡的狀態都由 Git 儲存庫定義。新叢集一建好，ArgoCD 會自動把 `k8s/` 目錄下的 YAML 同步進去。
  > 也就是說，人為的誤刪並不可怕，因為『真理的唯一來源 (Single Source of Truth)』都在 Git Repo 裡，這大幅取代了傳統依賴人工看手冊一步步重建的風險。」

### 🚨 尖銳題 4：「『作為 AP 與 Infra 溝通橋梁』這句話很好聽。但實務上，就算有 DevSecOps 管線，如果有很高權限的工程師因為半夜想省事，直接用 `kubectl` 下指令建了一個帶有特權 (Privileged) 卻沒經過掃描的 Pod 怎麼辦？」
* **面試官在想什麼**：你的安全防線是防君子還是防小人？你有沒有理解 Kubernetes Admission Controller 的極端防禦機制？
* **破局應答思維**：
  > 「這是個極佳的資安盲點。CI/CD 管線只能防得走正規流程的人，防不了擁有 Admin 權限的捷徑。
  > 為了解決這個問題，我在專案中導入了 **Kyverno** 實作 **Policy-as-Code (策略即代碼)**。它掛載在 K8s API 的 Admission Control 層。
  > 也就是說，就算這個工程師用 `kubectl` 直接對叢集發出請求，只要他的 YAML 裡帶有 `privileged: true`，K8s 核心就會直接退回這個請求並報錯。這將『人為宣導』轉換成了『系統強制力』，是企業架構防護的最後一道銅牆鐵壁。」

---

## 🛠️ 第三級別：Kubernetes 深層維運與底層除錯 (資深級難度)

### 🚨 尖銳題 5：「JD 要求『運行和維護、性能調校、問題排除』。如果有一天凌晨兩點接到 PagerDuty，某台 EKS Node 發生了 OOM (Out of Memory) 被強制重啟，Pod 被 Evict。你打開 Grafana，第一眼看哪裡？如何判斷是 Java 程式內存洩漏 (Memory Leak)，還是我們 K8S 的 Request/Limit 設定錯誤？」
* **面試官在想什麼**：辨別你是不是只會用 UI 點一點，但不懂底層 OS/Container 原理的工程師。
* **破局應答思維**：
  > 「第一眼我會調出 Kube-Prometheus 的 Node Exporter 與 cAdvisor 指標。
  > 1. **看 JVM vs K8S**：如果 Java 程式內部的 JVM Heap 曲線一直平穩上升沒有被 GC 釋放，且很快達到了 Pod 的 Limit 導致被 K8S 的 OOMKiller 砍掉，那大概率是 AP 端的 Memory Leak。我會要求 AP 提供 Heap Dump。
  > 2. **看 K8S 資源分配**：如果是程式本身行為正常，但 K8S 發出了 Node Memory Pressure 警告導致 Pod 遭到 Eviction，這代表我們當初沒有做好 Capacity Planning，讓太多沒有設定 Requests/Limits，或 Limits 給太大的 Pod 擠在同一台機器上。這時的解法是調整資源配額 (Resource Quota) 與 LimitRange，保證關鍵服務的 QoS 保證類別是 Guaranteed。」

### 🚨 尖銳題 6：「你熟悉 Argo Rollouts 的金絲雀。如果在 20% 的流量切換期間，發生了資料庫 Schema (欄位) 的變更，導致舊版程式 (80%) 存取資料庫報錯，你會怎麼規劃這種狀況的部署機制？」
*(請直接參考此情境的兩階段發佈 [Two-phase migration] 思維，向面試官展示您同時懂 K8S 與 Backend 運作邏輯。)*

## 🤖 第四級別：AI 協同作戰與資安防禦 (GenAI in DevOps)

隨著 AI (如 GitHub Copilot, ChatGPT, Gemini) 在開發領域的普及，面試官一定會想知道你是否具備「駕馭 AI」的能力，同時又不會踩到金融業的紅線。

### 🚨 尖銳題 7：「大家都說 AI 可以寫 Terraform 或幫忙除錯。你平常工作中會用 AI 嗎？我們壽險業最怕資料外流，你如何保證你用 AI 產生程式碼時，不會把公司的基礎架構或個資餵給公開的 LLM (大型語言模型)？」
* **面試官在想什麼**：你在追求效率的同時，有沒有資安敏感度 (Data Privacy)？
* **破局應答思維**：
  > 「我非常提倡使用 AI 來打造樣板代碼 (Boilerplate) 或撰寫自動化腳本，這能大幅提升 DevOps 的推進速度。
  > 但是在金融/壽險環境，『機密隔離』是首要原則。
  > 1. **資料脫敏與隔離管控**：我在架構中佈署了 **K8sGPT Operator** 來作為智能維運副手。而在設定後端模型時，我們絕對不會串接公開的 OpenAI API。
  > 2. **企業級 AI 落地 (Local LLM)**：做為企業架構團隊的一員，我會推動並配置 K8sGPT 直接串接公司內部私有部署的開源模型 (如 Llama 3) 或是具備『Zero Data Retention (無資料留存訓練)』合規認證的 Azure OpenAI。這樣一來，我們既能享受秒級的崩潰日誌分析 (Analyze)，又能從系統底層保證所有的 Namespace、Pod 架構配置 100% 留在公司內部。」

### 🚨 尖銳題 8：「AI 產生的 K8s YAML 或 Pipeline 雖然快，但有時候會出現『幻覺 (Hallucination)』，甚至夾帶安全漏洞。你怎麼審核這些 AI 幫你寫的代碼？」
* **面試官在想什麼**：你是不是盲目複製貼上的工程師？AI 取代了你敲鍵盤，那你的核心價值剩下什麼？
* **破局應答思維**：
  > 「這正是我們堅持建構 DevSecOps 與 GitOps 最大的價值所在！
  > AI 產生出來的 YAML，對我來說只是『不受信任的草稿』，它必須無條件進入 Pipeline 接受無情的機器掃描。
  > 1. **自動化攔截幻覺**：AI 寫出的代碼必須通過 Checkov 的 IaC 弱點掃描，以及 Kube-linter 的架構檢查。如果 AI 偷偷加了特權容器 (Privileged=true)，管線直接報錯擋下。
  > 2. **DevOps 工程師的核心價值進化**：AI 不懂公司的『業務邏輯』與『金管會標準』。在 AI 時代，我的職責從『寫程式的人』晉升為了『制定規則與建構防禦管線 (Pipeline) 的架構師』。只要自動化防線建得夠深，AI 就是我們團隊衝刺業務最強的擴充算力 (Copilot)。」

## 🌟 終極核心：面試官真正在乎的「底層知識點」與「企業級深度思維」

除了實戰指令與 AI 輔助，企業架構處 (Enterprise Architecture) 的面試官在面試這個職位時，真正想剝開來看的，是你的底盤穩不穩，以及你的眼界是不是在「架構師」的高度。

### ⚙️ 必備的三大核心技術底盤 (Core Knowledge)

1. **Kubernetes API 請求生命週期 (API Lifecycle & Admission Control)**
   - **面試官為什麼在乎**：只會寫 YAML 部署應用的人進不了企業架構處。主管想確認你知道一個請求進入 K8s 後，是經歷了 Authentication (你是誰) → Authorization (RBAC 審核) → **Admission Control (這就是我們放 Kyverno 防火牆的地方)** → 才被寫入 etcd。了解這個流程，證明你懂得如何從 API 基礎層級佈建企業級安全防線。
2. **狀態機理與漂移管理 (Drift Management)**
   - **面試官為什麼在乎**：你必須非常清楚 K8s 是不斷比對期望與實際狀態的迴圈 (Reconciliation Loop)，以及 Terraform 是透過 State 檔 (需搭配 S3 + DynamoDB Lock) 做資源對比的。面試官可能會問：「如果有人手動去 AWS 把設定改了，你該怎麼辦？」他們要聽的答案是：**自動化漂移偵測 (Drift Detection) 與強制還原機制**。
3. **可觀測性的三大支柱 (Metrics, Logs, Traces)**
   - **面試官為什麼在乎**：如果你講監控，只講得出 CPU/Memory (Metrics)，那只是助理工程師。在複雜的保單微服務網中，你一定要能說出建立 **關聯式日誌 (Centralized Logging)** 與 **分散式追蹤 (Distributed Tracing)**。這證明你有能力一眼看出流量是塞在哪一朵雲或哪一個微服務上。

### 🧠 企業架構處最需要的三大深度思維 (Deep Mindset)

1. **爆炸半徑控制 (Blast Radius) 與降級能力**
   - **深度展現 (你要說的話)**：「當我在設計 CI/CD 或是導入新架構時，我第一個思考的永遠不是『這工具多酷』，而是『萬一它壞了，影響範圍(爆炸半徑)有多大？』」我們專案中的 **Argo Rollouts (限縮錯誤在 20%)** 與 **Network Policy (微隔離網段)**，這就是企業防禦思維的具體產物。
2. **將「人為宣導」轉化為「系統強制力」 (Golden Path)**
   - **深度展現 (你要說的話)**：「在 5 個人的新創團隊，我們可以用開會約定不要亂開特權容器。但在 500 人的大型金控企業，我只相信程式碼強制力。」這就是為何我們非得導入 Kyverno 與管線阻斷的原因。企業架構處的工作，就是為開發團隊打造一條安全、無腦但不會翻車的「鋪裝道路 (Golden Path)」。
3. **業務連續性 (BCP) 重於一切敏捷**
   - **深度展現 (你要說的話)**：「我完全了解 DevOps 在業界主打敏捷與快速迭代。但我明白，對於壽險業核心系統而言，『穩定不可掉線與可被稽核』的權重，永遠高於『上線速度』。」你在專案裡實作的 **Velero 災難復原** 以及 **IRSA 最小許可權**，就是在向主管保證：你有能力在一堆駭客虎視眈眈的公有雲中，守住公司最後的資料生命線。

### 🔮 加碼籌碼：企業架構的前沿技術 (Cutting-edge Tech) 視野

當面試官問到：「對於未來的技術發展，你有什麼看法？」或是「若你進來企業架構處，未來 1~3 年的規劃會是什麼？」這是您展現「技術先鋒」籌碼的最佳時機。請準備好這兩個目前在國外頂級金控最火熱的關鍵字：

1. **從 DevOps 邁向「平台工程 (Platform Engineering)」**
   - **籌碼價值**：DevOps 發展到最後，很容易變成「DevOps 工程師在幫所有人寫 YAML 擦屁股」。
   - **破局話術**：「我認為企業架構處的未來，是打造『內部開發者平台 (IDP, 如下一代的 Backstage)』。也就是我們把剛才提到的 DevSecOps、Kyverno 安全策略全部打包成『自助服務 (Self-Service)』。讓 AP 開發人員點幾個按鈕，就能開出絕對符合金管會規範的 K8s 環境，徹底消弭開發與維運的對立。」
2. **基於 eBPF (如 Cilium) 的極限網安與觀測性**
   - **籌碼價值**：壽險業極度注重無死角的監控與底層安全。傳統在每個 Pod 塞 Sidecar 的做法十分浪費資源。
   - **破局話術**：「對於未來全新叢集的建置，我會推廣將 K8s 的網路 CNI 替換成基於 **eBPF (Extended Berkeley Packet Filter)** 的方案如 **Cilium**。它能從 Linux Kernel (作業系統核心) 層級做到零死角的網路監測與微隔離阻斷，且幾乎沒有效能耗損。這將是雲原生資安與 Telemetry 的最終極解法。」

---

## 🏢 第五級別：金融業日常維運 (Daily Governance & Compliance)

這個級別的問題，是為了確認你有沒有真正待過「規矩很多」的大型金融環境。

### 🚨 尖銳題 9：「在我們的環境中，資源是共享的。如果有一個部門的行銷網頁因為流量過大或程式 Bug (如 Memory Leak)，把整台 K8s Node 的記憶體吃光，導致另一個部門的『核心保單系統』停擺，你的架構如何防止這種『連鎖崩潰』？」
* **面試官在想什麼**：故障隔離 (Bulkheading)。你懂不懂資源配額與公平性的管理？
* **破局應答思維**：
  > 「這在多租戶環境中是非常嚴重的問題。我的解法是實作 **『層級化資源限額 (Tiered Quota)』**。
  > 1. **命名空間限制 (ResourceQuota)**：我會為每個業務部門或環境設定預設的資源總額，像是在 `k8s/08-resource-governance.yaml` 中定義的一樣。一旦該部門的使用量達到飽和，其餘 Pod 會進入 Pending，但不會搶佔到其他部門的『生存空間』。
  > 2. **強制請求與限制 (LimitRange)**：為了防止開發者忘記設定 Request/Limit，我透過 LimitRange 設定強制預設值與上限。這就像是在大樓的每個房間安裝獨立的保險絲，確保單一房間跳電不會影響整棟大樓的供電穩定。」

### 🚨 尖銳題 10：「金融稽核非常強調『審計導軌 (Audit Trail)』。如果發生了資安外洩，我們要怎麼知道這半個月內，誰更動過 Production 的 Secret？或者誰手動操作過 `kubectl`？」
* **面試官在想什麼**：監控與審計流程。你知不知道 K8s Audit Log。
* **破局應答思維**：
  > 「這是維運生命線。針對『變更審計』，我的應答包含三個層次：
  > 1. **Git 為真理來源 (GitOps Audit)**：因為我們採用 Azure Pipelines 與 GitOps，所有的變更（包含 Secret 的路徑更動）都必須經過 Pull Request 並留有 Git 歷史紀錄。這就是天然的『變更審計』。
  > 2. **EKS 控制面審計日誌 (Amazon EKS Audit Logs)**：我會開啟 EKS 的 Audit 指標並對接至 CloudWatch Logs。記錄所有 API 呼叫（誰、在什麼時間、對什麼資源、做了什麼事），這能追蹤到任何繞過管線的 `kubectl` 手動操作。
  > 3. **不可變基礎設施 (Immutability)**：我們禁止工程師直接進入容器。透過關閉 Pod 的特權模式 (Privileged=false, 如 Kyverno 策略所示)，確保維運人員無法隨意竄改運行中的代碼，所有變更必須透過標準管線重新佈署。」

### 🚨 尖銳題 11：「你說你在 EKS 中同時用了 EC2 Managed Node Groups 和 Fargate。這兩者的成本計算跟安全模型完全不同。身為架構師，你如何決定哪個微服務該跑在誰身上？有沒有具體的判斷標準？」
* **面試官在想什麼**：資源調度決策能力。你是不是亂選工具，還是有經過成本與風險評估？
* **破局應答思維**：
  > 「這是架構師必須面對的權衡 (Trade-off)。我設計了一套 **『三維度評估模型』**：
  > 1. **安全敏感度 (Security Isolation)**：如果服務涉及外部 API 直接呼叫或高度敏感的加解密，我會優先選 **Fargate**。因為它具備 Pod 等級的獨立 Micro-VM，能防止在 EC2 上可能發生的橫向滲透風險。
  > 2. **資源穩定性與持久化 (Persistence)**：如果服務需要掛載 EBS 磁碟或是需要透過 DaemonSet 進行底層監控 (如 Prometheus Node Exporter)，我會選擇 **EC2**。
  > 3. **成本效益 (Cost-Effectiveness)**：對於 24/7 穩定運行的核心服務，EC2 搭配預留實例 (RI) 較划算；但對於每天只跑 10 分鐘的清算批次 job，Fargate 的按秒計費 (Pay-as-you-go) 則能大幅降低閒置開銷。
  > 透過這種混合架構，我能幫助公司在『極致安全』與『成本負擔』之間取得最佳平衡點。」

### 🚨 尖銳題 12：「你在 JD 中看到我們要維護 MySQL 和 Redis。你在這個 EKS 專案中是如何規劃資料庫層的？為什麼不乾脆跑在 K8s 裡面用 StatefulSet 就好？」
* **面試官在想什麼**：確認你懂不懂 Managed Service 的價值。你是否有處理「真實生產環境數據」的謹慎度？
* **破局應答思維**：
  > 「對於電商或金融核心數據，我堅持 **『權責分離』**。
  > 1. 原則上，我優先選用 **AWS RDS (MySQL)**。因為它內建了跨可用區 (Multi-AZ) 高可用、自動備份快照、以及補丁更新，這能大幅降低 SRE 的 Day-2 維運負擔。
  > 2. 將資料庫放在 K8s 外部更能確保其生命週期與叢集解耦，避免叢集升級或故障影響數據完整性。當然，我也會透過 Terraform (如 `database.tf`) 定義 Security Group，確保只有 EKS Node 能存取，落實網路最小權限原則。」

### 🚨 尖銳題 13：「我們有多個環境 (Dev/Stage/Prod)。如果你是用傳統 YAML，配置很容易出錯。你是如何管理這些差異的？如果我們要快速複製一套新環境給新團隊，你的作法是什麼？」
* **面試官在想什麼**：模組化能力。你懂不懂 Helm 或 Kustomize？
* **破局應答思維**：
  > 「我採用 **Helm Chart** 實作模組化管理。
  > 1. 我將應用程式的佈署邏輯抽離成模板，並將環境差異 (如 CPU/Memory 配額、複本數) 參數化到 `values.yaml` 中。
  > 2. 這樣當我們需要建立新環境時，只需準備一個新的 `values-new-env.yaml` 檔案，幾秒鐘內就能透過同一套模板產出一致的環境，這徹底解決了 **環境漂移 (Environment Drift)** 的痛點。」

### 🚨 尖銳題 14：「我們的對外網站必須掛載 SSL 憑證。在 K8s 裡，你是如何處理 HTTPS 流量的？如果憑證過期了怎麼辦？」
* **面試官在想什麼**：網路與憑證基礎。你懂不懂 Ingress 與備援設計。
* **破局應答思維**：
  > 「我使用 **Ingress Controller (配合 AWS ALB)** 來管理入口流量。
  > 1. 我會在 Ingress 中定義 SSL 終端，並串接 **AWS ACM (Certificate Manager)** 的憑證。
  > 2. 為了更高級的自動化，我推薦導入 **Cert-manager** 結合 Let's Encrypt 或 Private CA。這讓憑證的申請、更新到重新掛載，都能在 K8s 內部自動完成，完全排除人為忘記更新導致服務中斷的風險。」

### 🚨 尖銳題 15：「我們現在正在導入 AI 與大語言模型 (LLM)，需要管理昂貴的 GPU 資源。身為 Kubernetes 工程師，你如何在 EKS 裡面優化這些資源的配置，防止一般應用程式搶佔 GPU，或者防止 GPU 被閒置？」
* **面試官在想什麼**：AI Infrastructure 管理能力。你懂不懂 Taints/Tolerations 以及 Node Affinity 的進階運用？
* **破局應答思維**：
  > 「這是我在架構規劃中非常重視的一環。
  > 1. **物理性隔離 (Taints/Tolerations)**：我會為具備 GPU 的節點池加上 Taint (如 `dedicated=gpu:NoSchedule`)，確保除非是帶有相對應 Tolerations 的 AI 排程 Pod，否則絕不會跑在這些高成本節點上。
  > 2. **精準調度 (Node Affinity)**：我會配置 Node Affinity 讓 LLM 推論任務強制靠近 GPU 標籤。
  > 3. **動態擴縮**：結合 Karpenter，我們可以做到只有當 AI 任務進來時，才動態開出 GPU 實例，任務結束立即回收，協助公司在 AI 轉型過程中控制雲端成本。」

### 🚨 尖銳題 16：「在電視台（如 TVBS）或電信業（如台哥大），任何一次變更導致的停機都是重大事故。你平常如何與開發團隊溝通『系統不穩定』這件事？如果他們堅持要上線一個還沒測試完的功能，你會怎麼應對？」
* **面試官在想什麼**：SRE 思維。你懂不懂 Error Budget 如何作為團隊溝通的橋樑？
* **破局應答思維**：
  > 「這就是我建立 **SLO (服務水準目標)** 的核心價值。
  > 1. 我不跟 AP 團隊吵技術，我跟他們談 **數據**。我為系統設定了 **99.95% 的可用性目標**。
  > 2. 當我們每個月的 **Error Budget (錯誤預算)** 快用盡時，我會出示報表告訴開發團隊：目前系統的穩定性已達到臨界點，根據 SRE 規範，我們會暫時攔截除緊急修複外的所有新功能發佈。這將『人與人的情緒對立』轉化為『數據驅動的決策』，確保公司在創新的同時，能守住『穩定性』這條紅線。」

### 🚨 尖銳題 17：「如果今天你突然被隔離或請長假，我們剩下的工程師要如何接手你的專案？你的維運知識都存在哪裡？」
* **面試官在想什麼**：團隊協作與管理能力。你是否具備編寫 Runbook 與建立知識庫的習慣？
* **破局應答思維**：
  > 「這正是我在專案中堅持實作 **『運維代碼化與制度化』** 的原因。
  > 1. **IaC 與 GitOps**：所有的基礎設施與佈署邏輯都在代碼裡，任何人看 Repo 都能接手。
  > 2. **Runbook (SRE 事件手冊)**：我為所有常見故障 (如 OOM, CrashLoop, Secret Rotation) 撰寫了詳細的 [Runbook](./07-incident-runbook.md)。這份文件詳列了診斷步驟與應變動作，這讓我個人的知識能被制度化地封包與傳遞。
  > 哪怕我不在現場，值班團隊也能按照手冊在 15 分鐘內排除 80% 的常見故障。這種『消弭人為依賴』的思維，是我為公司架構提供的價值保障。」

---

## 📚 題庫擴充：從基礎到巔峰 (Full Spectrum Question Bank)

這份題庫按難度排序，您可以根據面試進度進行自我模擬。

### 🟢 第一階段：簡單 (Junior Level - 基礎功)

1. **「請簡單解釋 Service 的 ClusterIP, NodePort, LoadBalancer 有什麼差別？」**
   - **建議答案**：`ClusterIP` 是叢集內部互通，外部連不到；`NodePort` 是在每台主機開一個連接埠，外部可透過 `IP:Port` 訪問；`LoadBalancer` 則是對接雲端（如 AWS ALB/NLB），最適合正式環境。
2. **「如何查看一個 Pod 的日誌 (Logs)？如果要即時追蹤 (Follow) 要加什麼參數？」**
   - **建議答案**：使用 `kubectl logs <pod-name>`。即時追蹤加 `-f` (Follow)。
3. **「Terraform 的 `plan` 指令是用來做什麼的？為什麼不能直接 `apply`？」**
   - **建議答案**：`plan` 是預覽變更，它是對比現有狀態與代碼後的差異。為了防止誤刪資源（如資料庫），必須先 `plan` 確認沒問題才 `apply`，這是生產環境的標準安全流程。
4. **「什麼是 Docker Image 的 Layer？如何讓 Image 變得更小？」**
   - **建議答案**：Dockerfile 每一行指令都會產生一個 Layer。優化方式包括：使用 **Multi-stage build**、選用輕量化基礎映像檔（如 **Alpine**）、以及將多個 `RUN` 指令合併成一行。

---

### 🟡 第二階段：中等 (Mid Level - 實作能力)

5. **「當你執行 `kubectl apply` 後，K8s 內部發生了什麼事？」**
   - **建議答案**：API Server 接收請求 ➔ 經過 **Admission Control (如 Kyverno 檢查)** ➔ 寫入 **etcd** 存放 ➔ Controller Manager 偵測到期望與實際狀態不符 ➔ Scheduler 決定 Pod 要去哪台 Node ➔ Kubelet 在 Node 上啟動容器。
6. **「你的 HPA 擴張了 Pod，但 AWS Node 資源不夠了怎麼辦？」**
   - **建議答案**：這需要 **Cluster Autoscaler** 或 **Karpenter** 的介入。當 Pod 因為 Node 資源不足而處於 Pending 狀態時，自動擴縮器會向 AWS 請求開啟新的 EC2 實例。
7. **「Liveness Probe 與 Readiness Probe 有什麼區別？」**
   - **建議答案**：`Liveness` 是檢查 Pod 是否還活著（壞了就重啟）；`Readiness` 是檢查服務是否準備好接流量（沒準備好就從 Service 的 Endpoints 移除）。在金融業，Readiness 非常重要，能防止使用者連到還在啟動中的服務。
8. **「Terraform 的 State 檔案如果不小心刪掉了，你有什麼辦法處理？」**
   - **建議答案**：如果沒有雲端備份（如 S3 Versioning），最好的方式是用 `terraform import` 挨個將現有資源載回新的 State。這也說明了為什麼在專案中，我會將 State 存放在 S3 並開啟 **Locking (DynamoDB)** 的重要性。

---

### 🟠 第三階段：困難 (Senior Level - 設計與廣度)

9. **「如何將跑在 VM 的 Java 程式遷到 EKS？如何確保資料不遺失？」**
   - **建議答案**：
     1. **容器化**：撰寫 Dockerfile 並建立映像檔。
     2. **數據遷移**：將地端 DB 遷至 **AWS RDS**。
     3. **存儲策略**：對於文件，使用 **EBS CSI Driver (如專案實作)** 並配置正確的 PV/PVC。
     4. **切換流量**：先用 Ingress 做流量測試，確認沒問題後再更換 DNS。
10. **「如果你有幾百個 Ingress 憑證過期，你會怎麼自動化管理？」**
    - **建議答案**：我會導入 **Cert-manager** 結合 AWS Route53 (DNS-01 Challenge)。它能自動向 Let's Encrypt 申請憑證並自動寫入 K8s Secret，Ingress 只需引用該 Secret，實現憑證生命週期自動化管理。
11. **「電信業高併發環境中，HPA 追不上流量，你有什麼優化手段？」**
    - **建議答案**：
      1. **預熱 (Pre-warming)**：針對已知促銷活動提前手動擴容。
      2. **降低冷卻期**：微調 HPA 的 `behavior` 參數讓擴張更激進。
      3. **Placeholder Pods**：利用 PriorityClass 建立低優先權的 Pod 佔位，流量來時直接搶佔它們的資源，實現秒級擴容。

---

### 🔴 第四階段：尖銳 (Elite/Architect Level - 終極壓力與治理)

12. **「(地獄題) 如果 AWS 帳號被駭，State 檔與配置都被刪除，你如何在 1 小時內恢復？」**
    - **建議答案**：
      「這正是 **GitOps** 的價值所在。我不依賴任何手動配置。
      1. 重新用 Terraform (IaC) 在 15 分鐘內拉起基礎設施（因為代碼在 GitHub/GitLab）。
      2. 重新啟動 **ArgoCD/Rollouts**。
      3. 因為『真理來源』在 Git 庫中，Argo 會立即偵測到新環境是空的，並根據 `k8s/` 目錄下的 YAML 自動將所有微服務同步回期望狀態。這就是宣告式基礎設施的終極防禦力。」
13. **「開發團隊抱怨 Kyverno 的安全策略太嚴格，你會怎麼協調？」**
    - **建議答案**：
      「我會採取 **『Audit 模式過渡』** 策略。
      1. 先將 Kyverno 策略改為 `Audit` (只紀錄不擋下)，給開發團隊兩週緩衝期去修復那些不合規的 YAML。
      2. 同時建立 **Golden Template (黃金模板)** 給他們參考，讓他們『無腦複製』就能合規。
      3. 緩衝期過後，為了守住金管會/公司的合規底線，我會重新切換回 `Enforce` 模式。這展現了 SRE 在『業務彈性』與『系統安全』之間的平衡能力。」
14. **「高 IOPS 的交易系統，你會如何選擇 Storage Class？」**
    - **建議答案**：
      1. 選用 **gp3** 或更高等級的 **io2** EBS 磁碟。
      2. 在 StorageClass 開啟 `volumeBindingMode: WaitForFirstConsumer` (如專案實作)，配合 **Topology-Aware Scheduling**，確保 Pod 與磁碟永遠在同一個可用區，將跨區延遲降到零。
      3. 對於最高等級的一致性要求，會搭配 **AWS EBS Multi-Attach** 或應用層的資料庫複製技術。

---
---

## 🏎️ 終極補強題庫：360 度無死角複習 (Master Quest Bank)

此清單補齊了專案周邊的 Linux、網路、雲端架構與團隊協作。

### 🏗️ 一、Linux、網路與 Git 分支 (維運基本功)
**1. (中等) 如果網站連不上了，你會如何初步排查？請描述你的工具鏈。**
- **建議答案**：這考驗排障邏輯。我會由外而內檢查：
  1. `ping` 或 `telnet`：檢查連線與 Port 是否通暢。
  2. `nslookup/dig`：確認 DNS 解析是否正確。
  3. `curl -I`：查看 HTTP 狀態碼 (如 502 Bad Gateway 可能是後端倒了)。
  4. `top/htop`：進入 Node 檢查 CPU/Memory 狀態。
  5. `df -h`：檢查磁碟空間（長日誌常導致空間爆滿使服務崩潰）。

**2. (簡單) 你們團隊怎麼使用 Git？如果有兩個工程師同時改同一個檔案，怎麼處理衝突？**
- **建議答案**：我們採用 **Git Flow (或 GitHub Flow)**。開發者在 Feature 分支作業，透過 Pull Request (PR) 進行代碼審查後才併入 main。若有 Conflict，需在在地端執行 `git merge` 或 `rebase` 解決衝突，並重新跑測試確認無誤後再上傳。

---

### ☁️ 二、AWS 高可用架載與 Terraform (基礎設施層)
**3. (困難) 你的專案用了 NAT Gateway。為什麼不讓 EKS 節點直接用 Public IP 連外網就好？**
- **建議答案**：這是 **金融資安標準**。
  - 將 EKS Node 放在 Private Subnet 搭配 **NAT Gateway**，可以確保主機「不直接暴露在網路上」，僅允許內部發起對外的請求（如抓取映像檔）。
  - 這能大幅減少被掃描器掃到並攻擊的「攻擊面 (Attack Surface)」。

**4. (中等) Terraform 的 `tfstate` 檔包含明文機密，你如何安全地管理它？**
- **建議答案**：
  1. **遠端後端 (Remote Backend)**：將 State 存放在 AWS S3，並開啟 S3 的伺服器端加密 (SSE)。
  2. **權限控管**：利用 IAM 限制只有部署管線才能讀取該 Bucket。
  3. **加鎖機制**：配合 DynamoDB 進行狀態鎖定，防止兩個人同時 `apply` 導致 State 損壞。

**4.5 (困難) 實戰踩雷題：在使用 Terraform 銷毀整個 EKS 叢集時，為什麼有時候 AWS 後台會殘留 EBS 磁碟區或 Load Balancer，甚至導致 VPC 無法刪除且持續扣款？你要如何解決？**
- **建議答案**：
  - **根本原因**：這是 IaC (Terraform) 與 K8s 控制迴圈生命週期不一致導致的。這些 EBS 磁碟或 Load Balancer 是由 K8s 內部的 Controller（如 EBS CSI Driver 或 Load Balancer Controller）動態向 AWS 建立的，Terraform 的 `tfstate` 完全不知情。
  - **災難發生**：如果直接執行 `terraform destroy`，Terraform 會直接把 EC2 節點砍掉。這導致負責去 AWS 刪除磁碟與網卡的 Controller 也跟著陣亡，來不及向 AWS 發出刪除 API 呼叫，這些實體資源就變成了「孤兒 (Orphaned Resources)」。
  - **解決方案**：標準的 SRE 拆除流程是，在叢集還活著的時候，先執行 `kubectl delete pvc --all` 與刪除 LoadBalancer Service/Ingress。確保 Kubernetes 已經指揮 AWS 刪除實體資源後，再交由 Terraform 執行基礎設施的最後拆除。這能展現我對系統邊界與雲端底層運作的深刻認知。

---

### ☸️ 三、Kubernetes 深層調度與故障 (底層邏輯)
**5. (尖銳) 發生「ImagePullBackOff」常見的原因有哪些？你如何修正？**
- **建議答案**：
  1. **映像檔名稱錯誤**：檢查 YAML 中的標籤。
  2. **憑證問題**：如果是 Private ECR，檢查 EKS Node 的 IAM Role 是否有權限拉取 (AmazonEC2ContainerRegistryReadOnly)。
  3. **網路問題**：檢查 NAT Gateway 是否掛了，或者 Pod 所在子網段無法連到 ECR。

**6. (困難) 什麼是 Pod Anti-Affinity (反親和性)？為什麼在生產環境中非常重要？**
- **建議答案**：
  - **反親和性** 確保相同的服務 (如多個 Replica 的 Frontend) 被分散在「不同」的 Node 或 Availability Zone 運行。
  - **重要性**：防止因為單一時體台故障 (Node failure) 或單一資料中心斷電 (AZ down) 導致該服務的所有 Pod 同時消失。這是高可用 (HA) 的核心保證。

---

### 🚀 四、CI/CD 與 GitOps 進階運作
**7. (尖銳) 你的 Argo Rollouts 支持 Canary (金絲雀)。如果不幸在切換到 50% 時發現資料庫連線池滿了，你會手動修嗎？**
- **建議答案**：
  - 「絕對不手動修改生產環境，這會導致 **Configuration Drift**。」
  - 正確做法：執行 `kubectl argo rollouts abort/undo` 將流量立即壓回 100% 舊版本。
  - 隨後在開發環境透過 IaC (YAML) 調大連線池設定，重新跑過 CI 流程，由管線自動佈署。這套流程保證了 **「變更的可回溯性」**。

---

### 👁️ 五、觀察力與 SRE (監控的靈魂)
**8. (困難) 監控中常說的「黃金信標 (Golden Signals)」是指哪四個？**
- **建議答案**：Latency (延遲)、Traffic (流量)、Errors (錯誤率)、Saturation (飽和度)。
  - 在面試時，我會強調我更在乎 **Saturation (飽和度)**，因為這是預測系統崩潰的先行指標。

**9. (尖銳) 如果 Prometheus 報警說某個服務頻繁重啟 (Restart)，但重啟後立刻又變綠色 (Healthy)，你會怎麼查？**
- **建議答案**：這通常是 **OOM (Out of Memory) 被 K8s 砍掉**。
  1. 查看 `kubectl describe pod` 尋找 `Last State: Terminated` 且原因是 `OOMKilled`。
  2. 打開 Grafana 查看該 Pod 消失前的 Memory 曲線，判斷是資源設定 (Limit) 太小，還是程式有洩漏。

---

### 🛠️ 六、現代化工具鏈與成本優化 (Final specialized topics)

**10. (中等) 你的專案用了 Terraform，有些公司用 Ansible。請問這兩者在維運上有什麼本質區別？你會如何配合使用？**
- **建議答案**：
  - **Terraform** 是「基礎設施即代碼 (IaC)」，擅長透過「宣告式」管理 **資源的生命週期** (如建 VPC, RDS)。
  - **Ansible** 是「配置管理工具」，擅長透過「指令式」進入 OS 內部 **安裝軟體與配置環境**。
  - **配合方式**：我會先用 Terraform 拉起 EKS 叢集與網路，再用 Ansible 進行 Node 上的底層優化或安裝特定代理程式。這能兼顧規模化與細節控管。

**11. (困難) 網訊電通提到的「成本優化」，你在這個 EKS 專案中是如何體現的？**
- **建議答案**：
  1. **Rightsizing**：透過 `08-resource-governance.yaml` 設定 `requests` 與 `limits`，避免 Pod 無限制佔用資源。
  2. **混合計算層**：常態流量用 EC2 (可選 Spot Instance)，敏感或突發流量用 Fargate (按秒計費)，減少閒置成本。
  3. **自動擴縮**：HPA 結合 Cluster Autoscaler，確保沒流量時 Node 數會自動降到最低。

**12. (尖銳) 華經資訊提到「研究並導入 Service Mesh (如 Istio)」。你認為在什麼情況下 K8s 才需要導入 Service Mesh？它會帶來什麼代價？**
- **建議答案**：
  - **何時導入**：當微服務數量暴增（數百個），且需要更複雜的 **流量百分比切分、mTLS 加密、或分散式鏈路追蹤 (Tracing)** 時。
  - **代價**：
    1. **資源開銷**：每個 Pod 都要掛一個 Sidecar (Envoy)，會消耗額外 CPU/Mem。
    2. **複雜度**：除錯難度提升，網絡延遲會略微增加。
  - **總結**：除非業務規模極大，否則優先使用 K8s 原生的 Service/Ingress 來保持架構簡潔。

**13. (尖銳) 台哥大提到了「供應鏈安全 (SBOM)」。你對容器映像檔的安全防護有哪些實踐？**
- **建議答案**：
  1. **映像檔掃描**：我在 CI 管線中整合了 **Trivy**，在 Image Push 之前就攔截高風險漏洞。
  2. **來源驗證**：只使用公司 Private ECR。
  3. **動態稽核**：透過 **Kyverno** 策略，禁止任何未經掃描或來自非法 Repo 的 Image 在叢集內運行。這就是所謂的 **「零信任 (Zero Trust)」** 容器安全模型。

---

## 🚩 魔鬼題：關於 AI 輔助開發的應對策略 (Handling AI-Related Questions)

**面對「這專案看起來很專業，是不是 AI 幫你寫的？」這種詰問時的最佳破局應答。**

### 🚨 尖銳題 18：「你的專案配置非常完美，甚至有些地方超出了你現在的資歷。這專案是 AI 幫你做出來的嗎？」

*   **面試官在想什麼**：他不是在質疑你不能用工具，而是在測試你是否 **「只會複製貼上（Script Kiddie）」** 還是真的 **「理解背後的架構設計」**。
*   **建議回答與定調**（分為三個層次）：

#### 1. 坦誠並定義 AI 為「效率擴張器」
> 「我確實大量使用了 AI 工具（如 Copilot / Claude / Antigravity）來輔助開發與編寫配置。我認為在 2025 年的 DevOps 領域， **『如何與 AI 協作』** 本身就是一項關鍵的專業技能。
>
> 就像我們用 IDE 代替筆記本寫程式，AI 幫我處理了繁瑣的語法細節，讓我能把精力集中在 **『系統架構的穩定性設計』** 與 **『跨工具的邏輯串接』** 上。」

#### 2. 強調「決策權」在於人類大腦
> 「AI 可以生成 YAML，但它無法替我思考 **金融服務的高合規性要求**。
>
> 為什麼專案中要導入 **Kyverno** 做 Admission Control？為什麼要捨棄 LoadBalancer 改用 **Ingress**？為什麼要配置 **External Secrets**？這些技術選型與安全策略的佈局，是我研究了人壽與電信業的實務痛點後所做的 **專業決策**。AI 是我的執行員，而我是這個架構的 **總監 (Architect)**。」

#### 3. 展現「深度代碼審查與解決衝突」的經歷
> 「在實作過程中，AI 給出的配置經常會與 EKS 1.31 的組件版本發生衝突。
>
> 例如，在配置 **Argo Rollouts** 與 **Ingress 控制器** 的連動時，我花了非常多時間進行 Debug 與日誌分析，這些都是 AI 無法替代的 **『實戰排除經驗』**。我可以詳細跟您解釋專案中每一行配置的用途、以及我在整合過程中解決掉的任何一個 Bug。
>
> 對我而言，AI 是加速我學習與交付的工具，而這份專案展示的是我 **『指揮與驗證』** 這些先進技術的能力。」

---

## 🚩 針對結業生/轉職者的「水平質疑」應對 (Handling Level-of-Experience Questions)

**背景：作為剛結業的工程師，如何合理解釋為什麼你的專案能達到資深工程師的治理水平？**

### 🚨 尖銳題 19：「你剛從雲端班結業，為什麼你的專案會包含 Argo Rollouts、Kyverno 這些連很多在職工程師都沒碰過的工具？是不是只是照著範本貼上去而已？」

*   **面試官在想什麼**：他想確認你的「知識廣度」是來自於 **死記硬背** 還是 **主動探索與理解**。
*   **建議回答與定調**：

#### 1. 承認基礎，強調「自我驅動」的延伸學習
> 「雲端班的課程確實給了我 EKS 與 CI/CD 的基礎體系。但我對自己的定位不只是『會動就好』。
>
> 在專案規劃階段，我主動研究了 **AWS Well-Architected Framework** 以及金融、電信業實務上的 **治理案例**。我發現業界最痛的點不是部署不上去，而是部署後的 **安全性故障與變更風險**。這就是為什麼我決定自主學習並導入 **Kyverno (策略治理)** 與 **Argo Rollouts (金絲雀發佈)**，我希望我的專案能對接業界最真實的挑戰。」

#### 2. 將「專案深度」與「應徵意圖」連結
> 「我知道很多結業生只寫簡單的 YAML。但我之所以把專案做到這種深度，是因為我非常重視 **[全球人壽/台灣大哥大/網訊]** 這種大型企業對於 **『合規與穩定度』** 的極高要求。
>
> 我想證明，雖然我目前的年資尚淺，但我已經準備好接受資深團隊的標準。這份專案代表了我對 **『SRE 治理文化』** 的高度認同與快速學習能力。」

#### 3. 邀請面試官進行「壓力測試」
> 「我可以詳細解說任何一個組件的選型原因。例如您可以隨便問我關於 **External Secrets** 如何解決 GitOps 指令式管理的短板，或是 **Fargate** 在我這個架構中扮演的安全隔離角色。
>
> 我不只是貼上代碼，我經歷了無數次 **Debug 與版本兼容性** 的困擾（例如 EKS 1.31 對某些 API 的廢棄），這些實戰過程讓我對這些高階工具有了根本性的理解。」

---

### 💡 向面試官傳遞的終極戰略：
當您能說出：**「我知道這對於初學者來說很難，但我選擇挑戰難的，因為這才是業界真正的日常。」** 

面試官對您的質疑會立刻轉化為一種 **「撿到寶」** 的驚喜感。

### 🚨 尖銳題 20：「K8s 預設的 RollingUpdate 已經很穩定了，為什麼你還要花力氣去裝 Argo Rollouts 來做 Canary？這不會增加維運複雜度嗎？」

*   **面試官在想什麼**：他想聽你對「穩定性」與「複雜度」之間的權衡。
*   **建議回答與定調**：

#### 1. 痛點切入：RollingUpdate 的「不可控性」
> 「這是我在研究金融與電信維運案例後的深刻心得。`RollingUpdate` 雖然能讓服務不中斷，但它最大的問題是 **『無法控制受影響面』**。一旦新版本有 API 邏輯錯誤，它會隨著更新進度最終覆蓋 100% 的用戶。
> 
> 在大流量環境下，這種『全量式的漸進更新』風險依然很高。」

#### 2. 強調 Canary 的「流量外科手術」特質
> 「我導入 **Canary**，是為了實現 **『流量外科手術』級的控制**。
> 
> 透過 Ingress 自動將流量精確地分割 10%。這 10% 的用戶就像是真的『金絲雀』。如果這 10% 用戶回報 500 Error，我能立刻停止發佈，此時 **90% 的用戶完全沒感覺**，他們還在穩定運行舊版本。這在維運上比起 RollingUpdate 要從 50% 甚至 80% 更新後才發現錯誤要安全得多。」

#### 3. 複雜度的權衡：自動化勝過手動操作
> 「雖然裝 Argo Rollouts 增加了一點組件負擔，但它換來的是 **『自動化的穩定性保證』**。比起人肉盯盤、人肉 `rollout undo`，這種宣告式的 Canary 配置才是最能消弭人為失誤、實現 AIOps 的基礎工程。」

---

## 🛡️ 深度技術專題 (Deep-Dive Special)
**這部分專門應付想「考倒你」或「測試你是否懂底層」的面試官。**

### 🚨 尖銳題 21：深度連動題 —— 「請解釋 EKS 的 IRSA (IAM Roles for Service Accounts) 到底是怎麼讓 Pod 拿到權限的？它的安全性為什麼比傳統的 Access Key 高？」

*   **考點**：OIDC (OpenID Connect) 身分聯邦。
*   **建議解答**：
    1.  **原理**：EKS 會啟動一個 **OIDC Identity Provider**。當一個 Pod 被賦予特定的 ServiceAccount 時，K8s 會自動在 Pod 內注入一個 `AWS_WEB_IDENTITY_TOKEN`。
    2.  **流程**：AWS SDK 會拿這個 Token 去向 AWS STS (Security Token Service) 換取一個「臨時」的 IAM Role 憑證。
    3.  **安全性**：
        - **無密鑰不墜地**：我們不需要在 K8s Secret 存任何 Access Keys。
        - **最小權限 (Least Privilege)**：每個 Pod 拿到的 Role 都是獨立的。
        - **自動失效**：臨時憑證會自動過期，大幅降低外洩風險。

### 🚨 尖銳題 22：策略治理題 —— 「Kyverno 是如何攔截不合規的資源的？如果 Kyverno 本身掛掉了，你的 Pod 還能啟動嗎？」

*   **考點**：Validating Webhook 與 `failurePolicy`。
*   **建議解答**：
    1.  **機制**：Kyverno 是註冊為 K8s 的 **Admission Webhook**。當我們執行 `kubectl apply` 時，API Server 會先將請求發送給 Kyverno 進行「審核」。
    2.  **容錯處理**：這取決於 Webhook 的 `failurePolicy`。在生產環境中，我們通常設定為 `Fail` (Kyverno 不動，大家都不能動) 以保證絕對安全；或者 `Ignore` (Kyverno 壞了就直接放行) 以保證業務不中斷。
    3.  **體現**：這展現了我對 **「高可用資安組件」** 的權衡能力。

### 🚨 尖銳題 23：進階發佈題 —— 「在你的 Argo Rollouts 配置中，你是如何定義『發佈失敗』的？如果新版本出錯但沒有崩潰 (Crash)，Canary 如何自動回滾？」

*   **考點**：AnalysisTemplate 與 Prometheus Metrics 整合。
*   **建議解答**：
    1.  **監控指標**：我會配置一個 `AnalysisTemplate`，讓 Argo 自動去問 Prometheus。
    2.  **回滾邏輯**：如果「錯誤率 > 5%」或「回應時間延遲 > 2s」，Argo 會自動判定為 `Failed` 並執行 **Auto-Rollback**。
    3.  **深度點**：我們不只看 Pod 是否為 Running (死活)，我們更在乎 **業務品質 (SLO)**。即使 Pod 活著但沒回應，系統也會自動切回舊版本。

### 🚨 尖銳題 24：機密管理題 —— 「如果 AWS Secrets Manager 無法連線，External Secrets Operator (ESO) 會發生什麼事？這會影響已經正在運行的 Pod 嗎？」

*   **考點**：Controller 運作模式與 K8s Secret 緩存。
*   **建議解答**：
    1.  **緩存機制**：ESO 是將 AWS 的機密「投影」到 K8s 原生的 Secret 中。即使 AWS API 目前連不上，已經產生的 K8s Secret **依然存在於叢集內**。
    2.  **影響**：已經運行的 Pod 不受影響，但「正在啟動」需要更新密碼的 Pod 則會因為拿不到新值而失敗。
    3.  **設計考量**：這就是為什麼我們要用 ESO 而非直接在程式中呼叫 AWS API 的原因 —— 它提供了一層 **「災難緩衝」**。

---

## 🎯 面試終極心法總結

面對「全球人壽」或「台灣大哥大」這類大型金融機構：
1. **永遠把「安全、合規」放在回答的第一順位**。
2. **展現「退路思維」**：任何工具都會出錯。面試官問你 A 發生了怎麼辦？你要回答 B（降級策略/回滾機制）。
3. **強調「自動化」是為了消弭「人為失誤」**，在金融業，人為的 `kubectl edit` 才是災難的源頭，所以你高度推崇 Terraform + CI/CD 管線。

只要您在面試時能適時地拋出「**在金融同業的實務場景中...**」或是「**針對我們壽險業的嚴格合規考量...**」這類開場白，並輔以上述的解答思路，絕對能讓總監級的主管對您刮目相看。祝面試大捷！

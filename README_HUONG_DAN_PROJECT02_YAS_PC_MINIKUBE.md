# Project02 YAS CI/CD + Observability — Hướng dẫn làm lại từ đầu trên PC

Bản này là hướng dẫn **làm lại sạch từ đầu**, ưu tiên độ ổn định. Sau các lỗi gặp ở Windows PowerShell/Jenkins Windows, hướng khuyến nghị là:

```text
Windows PC
└── WSL2 Ubuntu
    ├── Docker / Docker Desktop WSL integration
    ├── Minikube
    ├── kubectl
    ├── Helm
    ├── Jenkins chạy bằng jenkins.war ở port 9090
    └── Repo YAS + bộ script Linux trong ops/linux
```

Lý do chọn WSL2/Ubuntu: repo YAS có sẵn nhiều script Linux trong `k8s/deploy`, Jenkins chạy shell ổn định hơn, không gặp lỗi quote JSON/backslash của PowerShell nữa.

---

## 0. Mục tiêu đồ án

Luồng chính của đồ án:

```text
Developer push code lên branch
        ↓
GitHub Actions chạy CI
        ↓
Build Docker image theo service
        ↓
Tag image bằng commit id cuối cùng của branch
        ↓
Push image lên Docker Hub
        ↓
Developer vào Jenkins job developer_build
        ↓
Nhập branch cần deploy cho từng service
        ↓
Jenkins resolve branch → full commit SHA
        ↓
Jenkins deploy YAS core services lên Minikube
        ↓
Cung cấp URL/NodePort/Ingress để developer test
        ↓
Jenkins job developer_delete xóa môi trường test
```

Service giữ lại theo scope demo:

```text
product, cart, order, customer, inventory, tax, media, search,
storefront-bff, storefront-ui, backoffice-bff, backoffice-ui, swagger-ui
```

Service không deploy trong bản demo:

```text
payment, payment-paypal, debezium-connect, promotion, rating,
recommendation, sampledata, webhook, location
```

---

## 1. Yêu cầu PC trước khi làm

Khuyến nghị:

```text
RAM máy PC: tối thiểu 32GB nếu có thể
RAM cấp cho Minikube: 16GB
CPU cấp cho Minikube: 6 cores
Disk cho Minikube: 60GB
```

Nếu máy chỉ 16GB RAM, vẫn có thể thử:

```text
Minikube memory: 8192MB
Minikube CPU: 4 cores
```

Nhưng deploy full YAS + Observability sẽ dễ chậm. Khi đó hãy deploy core app trước, Observability làm sau.

---

## 2. Cài WSL2 Ubuntu

Mở PowerShell Admin trên Windows:

```powershell
wsl --install -d Ubuntu
```

Restart máy nếu Windows yêu cầu.

Mở Ubuntu terminal, cập nhật package:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl wget git unzip ca-certificates gnupg lsb-release apt-transport-https dos2unix jq
```

---

## 3. Cài Docker cho WSL2

Cách dễ nhất: dùng Docker Desktop trên Windows và bật WSL integration.

Trong Docker Desktop:

```text
Settings → Resources → WSL Integration → Enable integration with Ubuntu
```

Trong Ubuntu kiểm tra:

```bash
docker --version
docker info
```

Nếu `docker info` chạy được là OK.

---

## 4. Cài kubectl, Minikube, Helm, Java

Trong Ubuntu:

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# minikube
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube
rm minikube-linux-amd64

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Java cho Jenkins chạy local trong WSL
sudo apt install -y openjdk-21-jdk
```

Kiểm tra:

```bash
git --version
docker --version
kubectl version --client
minikube version
helm version
java -version
```

---

## 5. Clone repo YAS và copy kit

Clone fork của bạn, không nên sửa trực tiếp upstream:

```bash
mkdir -p ~/devops
cd ~/devops
git clone https://github.com/<your-github-user>/yas.git
cd yas
```

Copy kit vào root repo YAS. Sau khi copy xong, repo nên có:

```text
.github/workflows/project02-ci-dockerhub.yml
ops/linux/*.sh
ops/jenkins/Jenkinsfile.developer_build.linux
ops/jenkins/Jenkinsfile.developer_delete.linux
ops/istio/*.yaml
README_HUONG_DAN_PROJECT02_YAS_PC_MINIKUBE.md
```

Set quyền chạy:

```bash
chmod +x ops/linux/*.sh
```

Commit/push kit:

```bash
git add .github ops README_HUONG_DAN_PROJECT02_YAS_PC_MINIKUBE.md
git commit -m "Add Project02 CI/CD Minikube kit"
git push
```

---

## 6. Tạo Docker Hub token và GitHub Secrets

Vào Docker Hub:

```text
Account Settings → Personal access tokens → Generate new token
```

Trong GitHub repo:

```text
Settings → Secrets and variables → Actions → New repository secret
```

Tạo 2 secret:

```text
DOCKERHUB_USERNAME = username Docker Hub của bạn
DOCKERHUB_TOKEN    = token Docker Hub
```

---

## 7. Chạy CI trên GitHub Actions

Push lên branch `main` để build default image tag `main` và `latest`:

```bash
git checkout main
git commit --allow-empty -m "Trigger Project02 CI build"
git push
```

Vào GitHub:

```text
Actions → Project02 CI - Build and Push Docker Images
```

Chờ các job pass. Docker Hub cần có các image chính:

```text
<dockerhub-user>/yas-product:main
<dockerhub-user>/yas-cart:main
<dockerhub-user>/yas-order:main
<dockerhub-user>/yas-customer:main
<dockerhub-user>/yas-inventory:main
<dockerhub-user>/yas-tax:main
<dockerhub-user>/yas-media:main
<dockerhub-user>/yas-search:main
<dockerhub-user>/yas-storefront-bff:main
<dockerhub-user>/yas-backoffice-bff:main
<dockerhub-user>/yas-storefront:main
<dockerhub-user>/yas-backoffice:main
```

Frontend cũng được push thêm alias:

```text
<dockerhub-user>/yas-storefront-ui:main
<dockerhub-user>/yas-backoffice-ui:main
```

---

## 8. Start Minikube sạch trên PC

Tại root repo YAS:

```bash
./ops/linux/test-prereqs.sh
```

Start Minikube cấu hình khuyến nghị:

```bash
CPUS=6 MEMORY=16384 DISK_SIZE=60000mb ./ops/linux/start-minikube-pc.sh
```

Nếu PC chỉ đủ 8GB cho Minikube:

```bash
CPUS=4 MEMORY=8192 DISK_SIZE=50000mb ./ops/linux/start-minikube-pc.sh
```

Kiểm tra:

```bash
kubectl get nodes
kubectl get pods -A
```

---

## 9. Cài Helm repos và CRDs cần thiết

```bash
./ops/linux/install-helm-deps.sh
```

Lệnh này sẽ:

```text
- Add repo stakater
- Add repo prometheus-community
- Install Prometheus Operator CRDs
```

CRDs này cần cho ServiceMonitor trong Helm chart YAS.

---

## 10. Deploy infrastructure của YAS

YAS không chỉ có app services. Backend còn cần các dependency như:

```text
PostgreSQL, Keycloak, Redis, Kafka, Elasticsearch
```

Chạy wrapper chính thức:

```bash
./ops/linux/setup-yas-infra-official.sh
```

Bước này có thể lâu. Sau khi xong, kiểm tra:

```bash
kubectl get pods -A
```

Nếu một số service phụ như Debezium Connect không ổn, kit sẽ cố scale xuống vì demo không cần Debezium.

---

## 11. Deploy YAS core services bằng local script trước

Trước khi dùng Jenkins, deploy local một lần để xác nhận môi trường ổn.

Set biến môi trường:

```bash
export NAMESPACE_SUFFIX=dev01
export NAMESPACE=yas-dev01
export DOCKERHUB_USER=<dockerhub-user-của-bạn>
export DOMAIN_ROOT=yas.local.com
export ENABLE_ISTIO_INJECTION=false
export STRICT_ROLLOUT=true

export TAG_PRODUCT=main
export TAG_CART=main
export TAG_ORDER=main
export TAG_CUSTOMER=main
export TAG_INVENTORY=main
export TAG_TAX=main
export TAG_MEDIA=main
export TAG_SEARCH=main
export TAG_STOREFRONT_BFF=main
export TAG_BACKOFFICE_BFF=main
export TAG_STOREFRONT=main
export TAG_BACKOFFICE=main
```

Deploy:

```bash
./ops/linux/deploy-yas-core.sh
```

Nếu lỗi, không chạy Jenkins vội. Debug local trước.

Kiểm tra:

```bash
kubectl get pods -n yas-dev01 -o wide
kubectl get svc -n yas-dev01
kubectl get ingress -n yas-dev01
```

---

## 12. Cấu hình hosts file trên Windows

Lấy IP Minikube:

```bash
minikube ip
```

Lấy hướng dẫn host:

```bash
./ops/linux/get-access-urls.sh
```

Mở Notepad bằng quyền Administrator trên Windows, mở file:

```text
C:\Windows\System32\drivers\etc\hosts
```

Thêm các dòng tương tự:

```text
<minikube-ip> storefront.dev01.yas.local.com
<minikube-ip> backoffice.dev01.yas.local.com
<minikube-ip> api.dev01.yas.local.com
```

Truy cập:

```text
http://storefront.dev01.yas.local.com/
http://backoffice.dev01.yas.local.com/
http://api.dev01.yas.local.com/swagger-ui
```

NodePort URL:

```bash
minikube service storefront-bff -n yas-dev01 --url
minikube service backoffice-bff -n yas-dev01 --url
minikube service swagger-ui -n yas-dev01 --url
```

---

## 13. Chạy Jenkins trong WSL2

Tải Jenkins war:

```bash
mkdir -p ~/jenkins
cd ~/jenkins
wget https://get.jenkins.io/war-stable/latest/jenkins.war
```

Chạy Jenkins ở port 9090:

```bash
java -jar jenkins.war --httpPort=9090
```

Giữ terminal này mở. Trên Windows browser mở:

```text
http://localhost:9090
```

Unlock Jenkins bằng password in trong terminal hoặc file:

```bash
cat ~/.jenkins/secrets/initialAdminPassword
```

Chọn:

```text
Install suggested plugins
```

Cài thêm nếu thiếu:

```text
Git
Pipeline
Pipeline: SCM Step
Pipeline: Stage View
```

---

## 14. Tạo Jenkins job developer_build

Trong Jenkins:

```text
New Item → developer_build → Pipeline → OK
```

Phần Pipeline:

```text
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/<your-github-user>/yas.git
Branches to build: */main
Script Path: ops/jenkins/Jenkinsfile.developer_build.linux
```

Save.

Chạy:

```text
developer_build → Build with Parameters
```

Điền:

```text
NAMESPACE_SUFFIX = dev01
DOCKERHUB_USER = <dockerhub-user>
DOMAIN_ROOT = yas.local.com
Các branch còn lại = main
```

Nếu muốn test branch `dev_tax_service`:

```text
TAX_BRANCH = dev_tax_service
Các service khác = main
```

Jenkins sẽ resolve `dev_tax_service` thành full commit SHA và deploy image:

```text
<dockerhub-user>/yas-tax:<full-commit-sha>
```

---

## 15. Tạo Jenkins job developer_delete

```text
New Item → developer_delete → Pipeline → OK
```

Phần Pipeline:

```text
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/<your-github-user>/yas.git
Branches to build: */main
Script Path: ops/jenkins/Jenkinsfile.developer_delete.linux
```

Chạy với:

```text
NAMESPACE_SUFFIX = dev01
```

Job này xóa namespace:

```text
yas-dev01
```

---

## 16. Observability

Sau khi core YAS chạy ổn, mới deploy Observability. Không nên deploy observability khi core app còn lỗi.

```bash
./ops/linux/deploy-observability-light.sh
```

Lấy Grafana URL:

```bash
minikube service kube-prometheus-stack-grafana -n monitoring --url
```

Login:

```text
admin / admin
```

Chụp minh chứng:

```text
- monitoring namespace pods
- Grafana login
- Grafana dashboard hoặc Explore
- Prometheus targets nếu cần
```

---

## 17. Service Mesh optional

Chỉ làm khi phần core + observability ổn.

Xem:

```text
ops/istio/README_ISTIO_OPTIONAL.md
```

Minh chứng cần chụp:

```text
- mTLS policy
- AuthorizationPolicy
- VirtualService retry
- Kiali topology
- curl test allowed/blocked
```

---

## 18. Checklist minh chứng report

Chụp các hình sau:

```text
1. GitHub Actions chạy CI pass
2. Docker Hub có image tag main/latest và commit SHA
3. Minikube node Ready
4. Jenkins job developer_build parameters
5. Jenkins console output resolve branch tag
6. Jenkins deploy thành công
7. kubectl get pods -n yas-dev01
8. kubectl get svc -n yas-dev01, có NodePort
9. Mở storefront/backoffice/swagger
10. Jenkins developer_delete chạy được
11. Observability Grafana mở được
12. Nếu làm service mesh: Kiali topology và YAML policy
```

---

## 19. Troubleshooting nhanh

### TLS handshake timeout

Cluster đang nghẽn hoặc API server treo.

```bash
minikube stop
minikube start --wait=all --wait-timeout=10m
kubectl get nodes
```

Nếu vẫn lỗi:

```bash
minikube delete
CPUS=6 MEMORY=16384 ./ops/linux/start-minikube-pc.sh
```

### FailedMount configmap not found

Thường là chưa deploy `yas-configuration`.

```bash
helm list -n yas-dev01
kubectl get cm -n yas-dev01 | grep yas-configuration
```

Deploy lại:

```bash
./ops/linux/deploy-yas-core.sh
```

### Ingress host conflict

Bạn đang dùng trùng host ở namespace khác.

```bash
kubectl get ingress -A
kubectl delete namespace <namespace-cũ>
```

### ImagePullBackOff

Kiểm tra Docker Hub image/tag:

```bash
kubectl describe pod -n yas-dev01 <pod-name>
docker pull <dockerhub-user>/yas-product:main
```

Nếu image không tồn tại, chạy lại GitHub Actions CI.

### Pod CrashLoopBackOff

Xem log:

```bash
kubectl logs -n yas-dev01 deployment/product --tail=100
kubectl describe pod -n yas-dev01 <pod-name>
```

Thường là dependency infra chưa Ready: PostgreSQL, Keycloak, Redis, Kafka, Elasticsearch.

---

## 20. Câu viết vào report

```text
Nhóm sử dụng GitHub Actions cho giai đoạn CI. Khi developer push code lên bất kỳ branch nào, pipeline sẽ build Docker image cho các service YAS và tag image bằng full commit SHA của branch đó. Image sau đó được push lên Docker Hub.

Nhóm sử dụng Jenkins cho giai đoạn CD. Jenkins job developer_build được cấu hình dạng parameterized pipeline, cho phép developer nhập branch cần deploy cho từng service. Jenkins resolve branch thành commit SHA, sau đó deploy YAS core services lên Minikube bằng Helm. Các service không được chỉ định branch riêng sử dụng image tag main làm mặc định.

Nhóm sử dụng Minikube làm Kubernetes cluster local trên PC. Các service frontend/BFF/API documentation được expose để demo thông qua Ingress và NodePort. Observability được triển khai chung trong Project 02 bằng Prometheus/Grafana để truy cập và chụp minh chứng giám sát.
```

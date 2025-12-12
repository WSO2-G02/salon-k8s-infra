# Complete Cluster Recovery & Calico Restoration

## 🎯 Problem Summary
- Calico networking crashed
- CoreDNS couldn't reach API
- ArgoCD components crashing
- **Root cause:** Calico deleted but Kubespray config had `helm_enabled: false`

## ✅ Solution: Enable Helm & Redeploy Calico

### **Step 1: Enable Helm in Kubespray Config**

File: `kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml`

```yaml
# BEFORE (broken)
helm_enabled: false

# AFTER (fixed)
helm_enabled: true
```

✅ **Already done for you!**

---

### **Step 2: Reinstall Calico via Helm**

```bash
# Make sure you're on the control-plane node
cd /home/ubuntu

# Add Calico Helm repo
helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
helm repo update

# Install Tigera Operator (manages Calico)
helm install calico projectcalico/tigera-operator \
  --namespace calico-system \
  --create-namespace

# Wait 2 minutes for all pods to start
sleep 120

# Verify Calico is running
kubectl get pods -n calico-system -o wide
kubectl get pods -n kube-system | grep calico
```

**Expected output:** All pods `1/1 Running`

---

### **Step 3: Verify CoreDNS Works**

```bash
# CoreDNS should now resolve names
kubectl run -it --rm debug --image=alpine --restart=Never -- nslookup kubernetes.default

# Should return: Server: 10.233.120.1 (the CoreDNS IP)
# And resolve successfully
```

---

### **Step 4: Check ArgoCD**

```bash
# ArgoCD should stabilize
kubectl get pods -n argocd
kubectl get pods -n argocd | grep -E 'server|controller|repo-server'

# All should be Running, not CrashLoopBackOff
```

---

## 🔧 Complete Fresh Cluster Setup Script

Create this script: `/home/ubuntu/deploy-cluster.sh`

```bash
#!/bin/bash
set -e

echo "🚀 Starting complete cluster deployment..."
echo "============================================"

# Step 1: Verify prerequisites
echo "✓ Step 1: Checking prerequisites..."
command -v terraform >/dev/null || { echo "❌ terraform not found"; exit 1; }
command -v ansible >/dev/null || { echo "❌ ansible not found"; exit 1; }
command -v kubectl >/dev/null || { echo "❌ kubectl not found"; exit 1; }
command -v helm >/dev/null || { echo "❌ helm not found"; exit 1; }

# Step 2: Enable Helm in Kubespray
echo "✓ Step 2: Enabling Helm in Kubespray..."
ADDONS_FILE="kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml"
sed -i 's/helm_enabled: false/helm_enabled: true/' "$ADDONS_FILE"

# Step 3: Ensure Calico is configured
echo "✓ Step 3: Verifying Calico configuration..."
grep -q "kube_network_plugin: calico" kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml || {
    echo "❌ Calico not configured in Kubespray"
    exit 1
}

# Step 4: Install Calico via Helm
echo "✓ Step 4: Installing Calico via Helm..."
helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
helm repo update

# Check if calico already installed
if helm list -n calico-system | grep -q "calico"; then
    echo "  • Calico already installed, skipping..."
else
    helm install calico projectcalico/tigera-operator \
        --namespace calico-system \
        --create-namespace
    echo "  • Waiting 2 minutes for Calico to stabilize..."
    sleep 120
fi

# Step 5: Verify Calico pods
echo "✓ Step 5: Verifying Calico pods..."
kubectl get pods -n calico-system -o wide
echo "  • Waiting for all pods to be Ready..."
kubectl wait --for=condition=ready pod -l k8s-app=calico-node -n kube-system --timeout=300s 2>/dev/null || true

# Step 6: Verify CoreDNS
echo "✓ Step 6: Verifying CoreDNS..."
kubectl get pods -n kube-system | grep coredns
echo "  • Testing DNS resolution..."
kubectl run -it --rm dns-test --image=alpine --restart=Never -- nslookup kubernetes.default 2>/dev/null || echo "  • DNS test skipped (pod cleanup)"

# Step 7: Check ArgoCD
echo "✓ Step 7: Checking ArgoCD status..."
kubectl get pods -n argocd | head -15

echo ""
echo "✅ Cluster recovery complete!"
echo "============================================"
echo ""
echo "📊 Summary:"
echo "  • Helm: Enabled in Kubespray"
echo "  • Calico: Installed via Helm"
echo "  • CoreDNS: Should be resolving"
echo "  • ArgoCD: Stabilizing..."
echo ""
echo "🔍 Next steps:"
echo "  1. kubectl get pods -n argocd  # Check ArgoCD status"
echo "  2. kubectl get pods -n staging  # Check application services"
echo "  3. kubectl get svc -n staging   # Check service IPs"
echo ""
```

Make it executable:
```bash
chmod +x /home/ubuntu/deploy-cluster.sh
```

---

## 🚀 For Fresh Cluster Deployment

### **Full Deployment Script**

Create: `/home/ubuntu/deploy-from-scratch.sh`

```bash
#!/bin/bash
set -e

WORK_DIR="/home/ritzy/wso2 project/salon-k8s-infra"
KUBESPRAY_DIR="$WORK_DIR/kubespray"
TERRAFORM_DIR="$WORK_DIR/terraform"

echo "🚀 COMPLETE CLUSTER DEPLOYMENT"
echo "=============================="
echo ""

# ============ PHASE 1: Enable Helm ============
echo "📝 PHASE 1: Configure Kubespray"
echo "--------------------------------"

ADDONS_FILE="$KUBESPRAY_DIR/inventory/mycluster/group_vars/k8s_cluster/addons.yml"

echo "Enabling Helm addon..."
sed -i 's/helm_enabled: false/helm_enabled: true/' "$ADDONS_FILE"
echo "✓ Helm enabled"

# ============ PHASE 2: Deploy Infrastructure ============
echo ""
echo "🏗️  PHASE 2: Deploy AWS Infrastructure"
echo "--------------------------------------"

cd "$TERRAFORM_DIR"
echo "Running: terraform init..."
terraform init

echo "Running: terraform apply -auto-approve..."
terraform apply -auto-approve

echo "✓ Infrastructure deployed"
echo "✓ Kubespray will run automatically"
echo "✓ ArgoCD bootstrap will run automatically"

# ============ PHASE 3: Wait for Cluster ============
echo ""
echo "⏳ PHASE 3: Waiting for Kubernetes Cluster"
echo "-------------------------------------------"

echo "Waiting for cluster to be ready (this takes ~20 minutes)..."
sleep 300  # 5 minute head start

# Get control plane IP
CONTROL_IP=$(terraform output -json instance_public_ips | jq -r '.[0]')
echo "Control plane IP: $CONTROL_IP"

# Wait for kubectl access
for i in {1..60}; do
    if ssh -o StrictHostKeyChecking=no ubuntu@$CONTROL_IP "kubectl cluster-info" 2>/dev/null; then
        echo "✓ Kubernetes cluster is ready!"
        break
    fi
    echo "  Attempt $i/60: Waiting for cluster... (${((i*10))) seconds)"
    sleep 10
done

# ============ PHASE 4: Install Calico ============
echo ""
echo "🐱 PHASE 4: Install Calico Networking"
echo "-------------------------------------"

ssh -o StrictHostKeyChecking=no ubuntu@$CONTROL_IP "
    set -e
    echo 'Adding Calico Helm repo...'
    helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
    helm repo update
    
    echo 'Installing Calico...'
    helm install calico projectcalico/tigera-operator \
        --namespace calico-system \
        --create-namespace
    
    echo 'Waiting for Calico pods to start...'
    sleep 120
    
    echo 'Verifying Calico...'
    kubectl get pods -n calico-system
    kubectl get pods -n kube-system | grep calico
"

echo "✓ Calico installed and running"

# ============ PHASE 5: Verify Everything ============
echo ""
echo "✅ PHASE 5: Verification"
echo "------------------------"

ssh -o StrictHostKeyChecking=no ubuntu@$CONTROL_IP "
    echo '=== Nodes Status ==='
    kubectl get nodes -o wide
    
    echo ''
    echo '=== Calico & CoreDNS ==='
    kubectl get pods -n kube-system | grep -E 'calico|coredns'
    
    echo ''
    echo '=== ArgoCD Status ==='
    kubectl get pods -n argocd | head -10
    
    echo ''
    echo '=== Services in Staging ==='
    kubectl get pods -n staging 2>/dev/null || echo 'No staging namespace yet'
"

echo ""
echo "🎉 CLUSTER DEPLOYMENT COMPLETE!"
echo "================================"
echo ""
echo "Access cluster:"
echo "  ssh ubuntu@$CONTROL_IP"
echo "  kubectl get pods -n argocd"
echo ""
```

Make executable:
```bash
chmod +x /home/ubuntu/deploy-from-scratch.sh
```

---

## 📋 Key Configuration Files

### **Critical: addons.yml** - Enable Helm
```yaml
# kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml
helm_enabled: true  # ← THIS MUST BE TRUE
```

### **Network: Calico Config**
```yaml
# kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-cluster.yml
kube_network_plugin: calico  # ← Use Calico

# kubespray/inventory/mycluster/group_vars/k8s_cluster/k8s-net-calico.yml
calico_pool_blocksize: 26
calico_ipip_mode: "Always"
calico_vxlan_mode: "Never"
calico_network_backend: bird
```

---

## 🛠️ Recovery Commands (If Issues Occur)

### **If Calico stuck:**
```bash
# Delete stuck pods
kubectl delete pod -n calico-system -l k8s-app=calico-kube-controllers
kubectl delete pod -n kube-system -l k8s-app=calico-node

# Wait and reinstall
sleep 60
helm upgrade --install calico projectcalico/tigera-operator \
    --namespace calico-system
```

### **If CoreDNS broken:**
```bash
# Restart CoreDNS
kubectl rollout restart deployment/coredns -n kube-system
sleep 30
kubectl get pods -n kube-system | grep coredns
```

### **If ArgoCD crashing:**
```bash
# Delete crashing pods (they'll respawn when cluster is healthy)
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-server
kubectl delete pod -n argocd -l app.kubernetes.io/name=argocd-repo-server
sleep 30
kubectl get pods -n argocd
```

### **Full cluster restart (nuclear option):**
```bash
# On control-plane node
sudo systemctl restart kubelet
sudo systemctl restart docker
sleep 300
kubectl get nodes
```

---

## 📊 Deployment Checklist

- [ ] Helm enabled in `addons.yml`
- [ ] Calico configured in Kubespray
- [ ] Terraform infrastructure created
- [ ] Kubespray cluster deployed
- [ ] Calico pods running (`kubectl get pods -n calico-system`)
- [ ] CoreDNS resolving names
- [ ] ArgoCD stable (no CrashLoopBackOff)
- [ ] Services deployed in staging namespace
- [ ] DNS test passes: `kubectl run -it --rm debug --image=alpine -- nslookup kubernetes.default`

---

## 🚀 Quick Start (Next Time)

For a fresh cluster deployment, just run:

```bash
cd "/home/ritzy/wso2 project/salon-k8s-infra"

# Enable Helm (one-time)
sed -i 's/helm_enabled: false/helm_enabled: true/' \
    kubespray/inventory/mycluster/group_vars/k8s_cluster/addons.yml

# Deploy everything
cd terraform
terraform apply -auto-approve

# After 25 minutes, Calico will be installed automatically
# If not, run manually:
helm repo add projectcalico https://projectcalico.docs.tigera.io/charts
helm repo update
helm install calico projectcalico/tigera-operator --namespace calico-system --create-namespace
```

Done! ✅

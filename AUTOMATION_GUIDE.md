# Complete Automation Guide

## 🚀 Fully Automated Deployment

Everything is now automated! Here's the complete flow:

## The Automated Pipeline:

```
1. Terraform creates AWS infrastructure (VPC, EC2, ECR, IAM)
   ↓
2. Terraform generates Kubespray inventory
   ↓
3. You run Kubespray to create K8s cluster (one-time)
   ↓
4. Terraform automatically bootstraps ArgoCD:
   - Installs ArgoCD (if needed)
   - Deploys ECR credential helper
   - Deploys all microservices
   ↓
5. ArgoCD continuously syncs from Git
   ↓
6. Done! ✅
```

---

## 📝 Complete Deployment Commands:

### **Step 1: Deploy Infrastructure**
```bash
cd "/home/ritzy/wso2 project/salon-k8s-infra/terraform"

# Deploy everything
terraform init
terraform apply
```

This creates:
- ✅ VPC, subnets, security groups
- ✅ EC2 instances (4 nodes)
- ✅ ECR repositories (7 repos)
- ✅ IAM policies for ECR access
- ✅ Kubespray inventory file

---

### **Step 2: Deploy Kubernetes Cluster (One-time)**
```bash
cd "/home/ritzy/wso2 project/salon-k8s-infra/kubespray"

# Install Kubernetes with Kubespray
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b
```

This installs:
- ✅ Kubernetes cluster
- ✅ ArgoCD (via Kubespray addon)
- ✅ Istio (if enabled)
- ✅ Other addons

**Note:** This is the ONLY manual step. Run it once after terraform apply.

---

### **Step 3: Bootstrap ArgoCD Applications (Automated)**

#### Option A: Via Terraform (Recommended)
```bash
cd "/home/ritzy/wso2 project/salon-k8s-infra/terraform"

# This automatically runs after Kubespray completes
terraform apply
```

The bootstrap script automatically:
1. ✅ Checks if cluster is ready
2. ✅ Installs ArgoCD (if not present)
3. ✅ Creates staging namespace
4. ✅ Clones GitOps repo on control-plane
5. ✅ Deploys ECR credential helper
6. ✅ Runs ECR job to create secrets
7. ✅ Deploys all ArgoCD applications
8. ✅ Verifies deployment

#### Option B: Manually Run Bootstrap Script
```bash
cd "/home/ritzy/wso2 project/salon-k8s-infra/terraform"
bash bootstrap_argocd.sh
```

---

## 🎯 Complete End-to-End Flow:

```bash
# From scratch to running services:

# 1. Deploy infrastructure
cd "/home/ritzy/wso2 project/salon-k8s-infra/terraform"
terraform init
terraform apply  # Takes ~5 minutes

# 2. Deploy Kubernetes (ONE-TIME)
cd "../kubespray"
ansible-playbook -i inventory/mycluster/hosts.yaml cluster.yml -b  # Takes ~15-20 minutes

# 3. Bootstrap ArgoCD (AUTOMATIC)
cd "../terraform"
terraform apply  # Runs bootstrap automatically
# OR manually:
# bash bootstrap_argocd.sh

# 4. Verify everything
ssh ubuntu@<control-plane-ip>
kubectl get applications -n argocd
kubectl get pods -n staging
```

---

## ⏱️ Timeline:

| Step | Time | Status |
|------|------|--------|
| Terraform apply | ~5 min | ✅ Done |
| Kubespray deploy | ~15-20 min | ⏳ One-time manual |
| ArgoCD bootstrap | ~2-3 min | ✅ Automated |
| Pods starting | ~3-5 min | ✅ Automatic |
| **Total** | **25-33 min** | |

---

## 🔧 What Each Script Does:

### **bootstrap_argocd.sh**
```
1. Finds control-plane IP from Kubespray inventory
2. SSH to control-plane
3. Checks if cluster is ready
4. Installs ArgoCD (if needed)
5. Creates staging namespace
6. Clones salon-gitops repo
7. Deploys ECR credential helper
8. Runs ECR job immediately
9. Deploys all ArgoCD applications
10. Shows status
```

### **Terraform (argocd_bootstrap.tf)**
```
- Depends on: Kubespray inventory generation
- Triggers: When cluster instances change
- Executes: bootstrap_argocd.sh
- Result: Fully deployed application stack
```

---

## 🔍 Verification Commands:

```bash
# Check ArgoCD applications
ssh ubuntu@<control-plane-ip>
kubectl get applications -n argocd

# Check pods
kubectl get pods -n staging

# Check services
kubectl get svc -n staging

# Check ECR secrets
kubectl get secret ecr-registry-secret -n staging
kubectl get secret ecr-registry-secret -n argocd

# View logs of a specific pod
kubectl logs -f <pod-name> -n staging
```

---

## 🚨 Troubleshooting:

### **Bootstrap script fails with "Cannot SSH"**
```bash
# Check SSH key
ssh ubuntu@<control-plane-ip>

# If fails, add your key:
ssh-add ~/.ssh/salon-key

# Or specify key explicitly in script
```

### **ArgoCD apps stuck in "OutOfSync"**
```bash
# Force sync all apps
ssh ubuntu@<control-plane-ip>
kubectl get applications -n argocd -o name | xargs -I {} kubectl patch {} -n argocd --type merge -p '{"operation":{"sync":{"revision":"main"}}}'
```

### **Pods stuck in ImagePullBackOff**
```bash
# Re-run ECR credential job
kubectl delete job ecr-cred-initial -n kube-system
kubectl create job --from=cronjob/ecr-cred-helper ecr-cred-retry -n kube-system
```

---

## 🎯 Future Runs (After Initial Setup):

Once everything is set up, to deploy changes:

```bash
# Option 1: Just push to Git (ArgoCD auto-syncs)
git add .
git commit -m "Update service"
git push
# ArgoCD detects change and deploys automatically

# Option 2: Update infrastructure
cd terraform
terraform apply  # Updates infrastructure + re-runs bootstrap if needed
```

---

## 📊 What's Automated vs Manual:

| Task | Automated? | When |
|------|-----------|------|
| **AWS Infrastructure** | ✅ Terraform | Every apply |
| **Kubernetes Cluster** | ⚠️ One-time | ansible-playbook |
| **ArgoCD Install** | ✅ Script | Auto-checks |
| **ECR Helper Deploy** | ✅ Script | Every bootstrap |
| **App Deployments** | ✅ ArgoCD | Git push |
| **ECR Token Refresh** | ✅ CronJob | Every 6 hours |
| **Application Updates** | ✅ ArgoCD | Git push |

---

## 💡 Pro Tips:

1. **First run:** Takes ~25-30 minutes total
2. **Subsequent runs:** Only changed resources update
3. **Git-based deployment:** Just push to Git, ArgoCD handles deployment
4. **No kubectl needed:** Everything through Git and Terraform
5. **Rollback:** Just revert Git commit, ArgoCD syncs automatically

---

## ✅ Success Criteria:

After running automation, you should see:

```bash
kubectl get applications -n argocd
# All apps: Synced + Healthy

kubectl get pods -n staging
# All pods: Running

kubectl get secret ecr-registry-secret -n staging
# Secret exists

kubectl get cronjob -n kube-system
# ecr-cred-helper exists
```

---

**That's it! Everything is now automated!** 🚀

Just run:
1. `terraform apply` (creates infra)
2. `ansible-playbook` (creates cluster, one-time)
3. `terraform apply` again (bootstraps apps automatically)

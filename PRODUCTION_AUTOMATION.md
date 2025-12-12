# Production-Grade Deployment Guide

## 🎯 The Problem with Manual Steps

**Before (Manual):**
```bash
terraform apply          # Step 1
ansible-playbook ...     # Step 2 (manual!)
terraform apply          # Step 3 (why twice?!)
```

**After (Automated):**
```bash
terraform apply          # ONE COMMAND! ✅
# Everything happens automatically
```

---

## 🏭 How This Works (Production-Style)

### **Single Command Deployment**

```bash
cd "/home/ritzy/wso2 project/salon-k8s-infra/terraform"
terraform apply -auto-approve
```

**What happens automatically:**

```
1. Terraform creates AWS infrastructure
   └─ VPC, Subnets, Security Groups
   └─ EC2 instances (4 nodes)
   └─ ECR repositories (7 repos)
   └─ IAM policies
   └─ Generates Kubespray inventory
        ↓
2. Terraform triggers: deploy_kubespray.sh
   └─ Checks if cluster already exists (smart!)
   └─ If not, runs Kubespray automatically
   └─ Installs Kubernetes (15-20 min)
   └─ Installs ArgoCD addon
        ↓
3. Terraform triggers: bootstrap_argocd.sh
   └─ Waits for cluster to be ready
   └─ Creates staging namespace
   └─ Deploys ECR credential helper
   └─ Runs ECR job immediately
   └─ Deploys all ArgoCD applications
        ↓
4. ArgoCD syncs from Git
   └─ Deploys all 6 microservices
   └─ Auto-heals if changes detected
        ↓
5. DONE! All services running ✅
```

**Total time:** ~25-30 minutes for complete setup
**Manual commands:** ZERO!

---

## 🚀 Real Production Deployment (CI/CD)

In actual production, you'd use CI/CD. Here's the GitHub Actions version:

```yaml
# .github/workflows/infrastructure.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]
  workflow_dispatch:  # Manual trigger

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Configure AWS credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: ap-south-1
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
    
    - name: Terraform Init
      run: terraform init
      working-directory: terraform
    
    - name: Terraform Plan
      run: terraform plan
      working-directory: terraform
    
    - name: Terraform Apply
      run: terraform apply -auto-approve
      working-directory: terraform
    
    - name: Verify Deployment
      run: bash verify_deployment.sh
      working-directory: terraform
    
    - name: Notify Slack
      if: always()
      run: |
        curl -X POST ${{ secrets.SLACK_WEBHOOK }} \
          -d "{'text':'Deployment completed: ${{ job.status }}'}"
```

**Now deployment is:**
```
git add .
git commit -m "Update infrastructure"
git push
# GitHub Actions handles the rest automatically!
```

---

## 📊 Comparison: Manual vs Automated vs Production

| Aspect | Manual | Your Setup | Production CI/CD |
|--------|--------|------------|------------------|
| **Commands** | 5+ manual | 1 command | Git push only |
| **Time** | 30+ min | 25-30 min | 25-30 min |
| **Human wait** | Constant | Set & forget | Zero |
| **Error prone** | High | Low | Very Low |
| **Reproducible** | No | Yes | Yes |
| **Auditable** | No | Partial | Full |
| **Rollback** | Manual | Manual | Automated |
| **Multi-env** | Duplicate work | Easy | Automatic |

---

## 🎮 How to Use Your New Setup

### **First Time (Complete Setup)**
```bash
cd "/home/ritzy/wso2 project/salon-k8s-infra/terraform"
terraform init
terraform apply -auto-approve
```

**Go get coffee ☕ - Takes ~25-30 minutes**

### **Check Status**
```bash
# While it's running, watch progress in another terminal
watch -n 5 'terraform show | grep "null_resource"'

# Or check the logs
tail -f /tmp/terraform-*.log
```

### **After Deployment**
```bash
# SSH to control-plane
ssh ubuntu@$(terraform output -json instance_public_ips | jq -r '.[0]')

# Verify everything
kubectl get applications -n argocd
kubectl get pods -n staging
kubectl get svc -n staging
```

### **Update Application (GitOps)**
```bash
# Make changes to your code
cd "/home/ritzy/wso2 project/salon-gitops"
git add .
git commit -m "Update service"
git push

# ArgoCD detects change and deploys automatically!
# No terraform apply needed!
```

### **Update Infrastructure**
```bash
# Change Terraform config
cd "/home/ritzy/wso2 project/salon-k8s-infra/terraform"
vim variables.tf  # Make changes

# Apply
terraform apply -auto-approve
# Only changed resources update
```

---

## 🔄 Day-to-Day Operations

### **Scenario 1: Deploy new microservice**
```bash
1. Add service to ECR list in variables.tf
2. Create deployment files in salon-gitops/staging/new_service/
3. Create ArgoCD app in salon-gitops/argocd/new_service.yaml
4. terraform apply  # Creates ECR repo
5. git push  # ArgoCD deploys automatically
```

### **Scenario 2: Update existing service**
```bash
1. Push new image to ECR
2. Update image tag in salon-gitops/staging/service/deployment.yaml
3. git push
# ArgoCD syncs and deploys automatically
```

### **Scenario 3: Scale infrastructure**
```bash
1. Change desired_capacity in variables.tf
2. terraform apply
# New nodes added, Kubernetes auto-scales
```

### **Scenario 4: Disaster recovery**
```bash
# Everything destroyed? No problem!
terraform apply -auto-approve
# Entire stack rebuilt from code
```

---

## 💡 Production Enhancements (Future)

### **Add to GitHub Actions:**
```yaml
- Approval gates for production
- Automated testing
- Canary deployments
- Automatic rollback on failure
- Slack/Teams notifications
- Cost estimation
- Security scanning
```

### **Add to Infrastructure:**
```yaml
- Multiple environments (dev/stage/prod)
- Secrets management (AWS Secrets Manager)
- Monitoring (Prometheus/Grafana)
- Logging (ELK/Loki)
- Backup automation (Velero)
- Certificate management (cert-manager)
```

---

## 🎯 Migration to Managed Kubernetes (EKS)

For even better automation, migrate to EKS:

```hcl
# Instead of Kubespray
resource "aws_eks_cluster" "main" {
  name = "salon-cluster"
  # Terraform creates cluster directly!
}

# ArgoCD bootstraps immediately
resource "helm_release" "argocd" {
  depends_on = [aws_eks_cluster.main]
  # No waiting for Ansible!
}
```

Benefits:
- ✅ Faster deployment (~10 min vs 20 min)
- ✅ AWS manages control plane
- ✅ Auto-updates
- ✅ Better security
- ✅ Easier scaling

---

## 📈 Metrics You Should Track

```yaml
- Deployment time: < 30 minutes ✅
- Manual steps: 0 (after initial setup) ✅
- Failed deployments: < 5% (target)
- Rollback time: < 5 minutes (target)
- Recovery time: < 30 minutes ✅
```

---

## ✅ Success Checklist

After `terraform apply` completes:

```bash
# 1. Infrastructure created
terraform state list | grep aws_

# 2. Kubernetes running
ssh ubuntu@$(terraform output -json instance_public_ips | jq -r '.[0]') "kubectl cluster-info"

# 3. ArgoCD installed
ssh ubuntu@$(terraform output -json instance_public_ips | jq -r '.[0]') "kubectl get pods -n argocd"

# 4. Applications deployed
ssh ubuntu@$(terraform output -json instance_public_ips | jq -r '.[0]') "kubectl get applications -n argocd"

# 5. Services running
ssh ubuntu@$(terraform output -json instance_public_ips | jq -r '.[0]') "kubectl get pods -n staging"
```

All should return success! ✅

---

## 🚨 Important Notes

**Smart Deployment:**
- Script checks if cluster already exists
- Won't re-deploy if already running
- Safe to run `terraform apply` multiple times

**Idempotent:**
- Running twice won't break anything
- Only missing pieces get deployed

**Error Handling:**
- Scripts fail fast with clear errors
- Can resume from failure point
- Logs available for debugging

---

## 🎉 Bottom Line

**You now have production-style automation!**

```
Before: terraform apply → (wait) → ansible → (wait) → terraform apply
After:  terraform apply → (grab coffee) → DONE! ✅
```

**No manual steps. No typing commands. Just code!** 🚀

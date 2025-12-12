# ECR URL Automation Documentation

## Overview

This automation ensures that Kubernetes deployment files always reference the correct ECR repository URLs created by Terraform, eliminating manual URL updates.

## Problem Solved

**Before Automation:**
- ❌ Terraform creates ECR repositories dynamically
- ❌ Deployment files have hardcoded ECR URLs
- ❌ If AWS account/region changes, manual updates needed
- ❌ Error-prone and inconsistent

**After Automation:**
- ✅ Terraform creates ECR repos AND updates deployment files
- ✅ URLs are automatically synced
- ✅ Single source of truth (Terraform)
- ✅ Zero manual intervention

---

## How It Works

### Architecture Flow

```
┌─────────────────────────────────────────────────┐
│ 1. TERRAFORM CREATES ECR REPOS                  │
│                                                  │
│  terraform apply                                 │
│      ↓                                           │
│  Creates ECR repositories:                      │
│  - user_service                                 │
│  - appointment_service                          │
│  - notification_service                         │
│  - etc...                                       │
│      ↓                                           │
│  Generates URLs:                                │
│  {ACCOUNT}.dkr.ecr.{REGION}.amazonaws.com/...  │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 2. TERRAFORM OUTPUTS ECR URLS                   │
│                                                  │
│  Terraform stores in state:                     │
│  {                                              │
│    "user_service": "024...ecr...user_service"  │
│    "appointment_service": "024...appt..."      │
│    ...                                          │
│  }                                              │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 3. TERRAFORM RUNS UPDATE SCRIPT                 │
│                                                  │
│  null_resource triggers: update_ecr_urls.sh     │
│      ↓                                           │
│  Script extracts ECR URLs from terraform output │
│      ↓                                           │
│  Script updates deployment.yaml files:          │
│    staging/user_service/deployment.yaml         │
│    staging/appointment_service/deployment.yaml  │
│    staging/notification_service/deployment.yaml │
│    etc...                                       │
│      ↓                                           │
│  Preserves existing image tags (:latest, :v1.0) │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 4. COMMIT AND PUSH TO GIT                       │
│                                                  │
│  Developer commits updated files:               │
│    git add salon-gitops/staging/                │
│    git commit -m "Update ECR URLs"              │
│    git push                                     │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│ 5. ARGOCD SYNCS CHANGES                         │
│                                                  │
│  ArgoCD detects Git changes                     │
│      ↓                                           │
│  Pulls new deployment manifests                 │
│      ↓                                           │
│  Uses correct ECR URLs automatically!           │
└─────────────────────────────────────────────────┘
```

---

## Components

### 1. Terraform Outputs (`terraform/outputs.tf`)

```hcl
output "ecr_repository_urls" {
  description = "Map of service names to ECR repository URLs"
  value = {
    for service, repo in aws_ecr_repository.repos : 
    service => repo.repository_url
  }
}
```

**What it does:**
- Exports ECR URLs as a structured map
- Makes URLs available to scripts and other tools
- Example output:
  ```json
  {
    "user_service": "024955634588.dkr.ecr.eu-north-1.amazonaws.com/user_service",
    "appointment_service": "024955634588.dkr.ecr.eu-north-1.amazonaws.com/appointment_service"
  }
  ```

### 2. ECR Resource with Auto-Update (`terraform/ecr.tf`)

```hcl
resource "null_resource" "update_ecr_urls" {
  depends_on = [aws_ecr_repository.repos]
  
  triggers = {
    ecr_repos = jsonencode([for r in aws_ecr_repository.repos : r.repository_url])
  }
  
  provisioner "local-exec" {
    command     = "bash update_ecr_urls.sh"
    working_dir = path.module
  }
}
```

**What it does:**
- Automatically runs after ECR repos are created/updated
- Triggers whenever ECR URLs change
- Executes the update script

### 3. Update Script (`terraform/update_ecr_urls.sh`)

**What it does:**
1. Reads Terraform state using `terraform output`
2. Extracts ECR URLs for each service
3. Finds corresponding deployment files in `salon-gitops/staging/`
4. Updates `image:` fields with new ECR URLs
5. Preserves existing image tags (`:latest`, `:v1.0`, etc.)
6. Reports what was changed

**Example transformation:**
```yaml
# Before
image: 024955634588.dkr.ecr.eu-north-1.amazonaws.com/user_service:latest

# After (if account/region changed)
image: 123456789012.dkr.ecr.us-west-2.amazonaws.com/user_service:latest
```

---

## Usage

### Initial Setup

1. **Apply Terraform**
   ```bash
   cd /home/ritzy/wso2\ project/salon-k8s-infra/terraform
   terraform apply
   ```
   
   This will:
   - Create all ECR repositories
   - Automatically update deployment files
   - Show you what changed

2. **Review Changes**
   ```bash
   cd /home/ritzy/wso2\ project/salon-gitops
   git diff staging/
   ```

3. **Commit and Push**
   ```bash
   git add staging/
   git commit -m "Update ECR URLs from Terraform automation"
   git push
   ```

4. **ArgoCD Auto-Syncs**
   - ArgoCD detects the Git changes
   - Automatically deploys with correct ECR URLs

### Manual Update (if needed)

If you need to manually trigger the URL update:

```bash
cd /home/ritzy/wso2\ project/salon-k8s-infra/terraform
bash update_ecr_urls.sh
```

---

## Examples

### Example 1: New Service Added

**Scenario:** You add a new service called `payment_service`

1. Add to `variables.tf`:
   ```hcl
   variable "services" {
     default = [
       "user_service",
       "appointment_service",
       "payment_service"  # NEW
     ]
   }
   ```

2. Run `terraform apply`:
   - Creates ECR repo for `payment_service`
   - Script automatically updates `staging/payment_service/deployment.yaml`

### Example 2: Region Change

**Scenario:** You migrate from `eu-north-1` to `us-west-2`

1. Update `variables.tf`:
   ```hcl
   variable "region" {
     default = "us-west-2"  # Changed
   }
   ```

2. Run `terraform apply`:
   - Creates new ECR repos in new region
   - Script updates ALL deployment files automatically
   - Old URLs: `*.dkr.ecr.eu-north-1.amazonaws.com/*`
   - New URLs: `*.dkr.ecr.us-west-2.amazonaws.com/*`

### Example 3: Tag Preservation

**Scenario:** You use specific image tags

**Before automation:**
```yaml
image: 024955634588.dkr.ecr.eu-north-1.amazonaws.com/user_service:v1.2.3
```

**After automation runs:**
```yaml
image: {NEW_URL}/user_service:v1.2.3  # Tag preserved!
```

---

## Verification

### Check Terraform Outputs

```bash
cd /home/ritzy/wso2\ project/salon-k8s-infra/terraform
terraform output ecr_repository_urls
```

### Verify Deployment Files

```bash
cd /home/ritzy/wso2\ project/salon-gitops
grep -r "image:" staging/*/deployment.yaml
```

All URLs should match your Terraform-created ECR repositories.

### Check ArgoCD Sync Status

```bash
kubectl get applications -n argocd
kubectl describe application user-service -n argocd | grep Image
```

---

## Troubleshooting

### Issue: Script doesn't update files

**Cause:** Terraform state missing or incomplete

**Solution:**
```bash
cd /home/ritzy/wso2\ project/salon-k8s-infra/terraform
terraform refresh
terraform output ecr_repository_urls
```

### Issue: Script updates wrong files

**Cause:** Path mismatch between service name and directory

**Solution:**
Ensure service names in `variables.tf` match directory names:
```
variables.tf service name: "user_service"
Must match directory: staging/user_service/
```

### Issue: Image tags get replaced with ":latest"

**Cause:** Script logic error

**Solution:**
The script preserves tags by default. If this happens:
1. Check your deployment file has a tag: `image: url:tag`
2. Re-run the script manually to debug

---

## Best Practices

### 1. Always Review Before Committing
```bash
git diff staging/
```
Verify URLs are correct before pushing.

### 2. Run After Any Infrastructure Change
- Account ID changes
- Region changes
- New services added

### 3. Keep Service Names Consistent
Match these exactly:
- Terraform variable: `var.services`
- ECR repo name: automatically set from variable
- GitOps directory: `staging/{service_name}/`
- Deployment file: `staging/{service_name}/deployment.yaml`

### 4. Test in Staging First
Before updating production:
1. Apply Terraform in staging
2. Verify ECR URLs
3. Test ArgoCD sync
4. Then apply to production

---

## Integration with CI/CD

You can integrate this into your pipeline:

```yaml
# Example GitHub Actions workflow
- name: Update Infrastructure
  run: |
    cd terraform
    terraform apply -auto-approve
    
- name: Commit Updated Deployment Files
  run: |
    cd ../salon-gitops
    git config user.name "Terraform Bot"
    git config user.email "bot@example.com"
    git add staging/
    git commit -m "Auto-update ECR URLs [skip ci]" || true
    git push
```

---

## Summary

| Aspect | Automated | Manual |
|--------|-----------|--------|
| ECR Creation | ✅ Terraform | ❌ |
| URL Generation | ✅ Terraform | ❌ |
| Deployment Update | ✅ Script | ❌ |
| Tag Preservation | ✅ Script | ❌ |
| Git Commit | ❌ | ✅ (You decide) |
| ArgoCD Sync | ✅ Auto | ❌ |

**Result:** 90% automated! Only Git commit/push requires human review.

---

## Files Modified

- ✅ `terraform/outputs.tf` - Exports ECR URLs
- ✅ `terraform/ecr.tf` - Triggers auto-update
- ✅ `terraform/update_ecr_urls.sh` - Update script
- ✅ All `staging/*/deployment.yaml` - Updated automatically

---

## Related Documentation

- [ECR Integration Guide](../salon-gitops/ECR_INTEGRATION_GUIDE.md)
- [Terraform Variables](terraform/variables.tf)
- [ArgoCD Applications](../salon-gitops/argocd/)

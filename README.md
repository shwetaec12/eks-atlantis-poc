# Atlantis EKS Setup with Terraform

This project provisions an AWS EKS cluster and deploys Atlantis using Helm. Atlantis is configured to use IAM Roles for Service Accounts (IRSA) for secure AWS access.

## 📦 Modules Overview

1. **vpc Module**  
Provisions the Virtual Private Cloud where EKS and other resources run.  
- Creates public/private subnets  
- Sets up route tables, NAT gateways  
- Defines CIDR blocks  

2. **eks Module**  
Creates the EKS cluster.  
- Provisions the control plane and node groups  
- Outputs kubeconfig for usage  
- Configures OIDC provider (for IRSA)  

3. **iam Module**  
Creates IAM roles and policies.  
- IRSA role for Atlantis  
- Inline/custom policies for S3, DynamoDB, ECR, KMS  
- Trust policy for sts:AssumeRoleWithWebIdentity  

4. **helm Module**  
Deploys Atlantis via Helm on the EKS cluster.  
- Uses IRSA for AWS permissions  
- Configures GitHub credentials, webhooks, and storage backend  
- Optional PVC and volume storage  

## 🚀 Deployment Steps

1. **Initialize Terraform**

```bash
terraform init
```

2. **Review the plan**

```bash
terraform plan
```

3. **Apply the configuration**

```bash
terraform apply
```

4. **Update kubeconfig**

```bash
aws eks update-kubeconfig --region eu-central-1 --name poc-eks-cluster
```

5. **Check AWS IAM identity**

```bash
aws sts get-caller-identity
```

6. **Access Atlantis**

Get the LoadBalancer or port-forward:

```bash
kubectl get svc -n atlantis
kubectl port-forward svc/atlantis 4141:80 -n atlantis
```

## 🧪 Debugging & Common Issues

### ❌ aws-auth ConfigMap Error

```
Get "http://localhost/api/v1/namespaces/kube-system/configmaps/aws-auth": dial tcp [::1]:80: connectex: No connection could be made...
```

**✅ Fix:**

- Ensure you run `aws eks update-kubeconfig` after creating the cluster.  
- Check if your kubeconfig context is set correctly.  
- Test with:

```bash
kubectl get nodes
```

### ❌ Terraform STS AssumeRoleWithWebIdentity Error

```
error AccessDenied: Not authorized to perform sts:AssumeRoleWithWebIdentity
```

**✅ Fix:**

Ensure your IRSA role trust policy is correct:

```bash
aws iam update-assume-role-policy --role-name atlantis-irsa-role --policy-document file://modules/iam/policies/trust-policy.json
```

Double-check the OIDC URL in the trust policy matches the output from:

```bash
aws eks describe-cluster --name poc-eks-cluster --query "cluster.identity.oidc.issuer"
```

### ❌ KMS Access Denied

```
kms:DescribeKey AccessDeniedException
```

**✅ Fix:**

Grant Atlantis IRSA role access to the KMS key:

```bash
aws kms put-key-policy --key-id <KEY_ID> --policy-name default --policy file://modules/iam/policies/key-policy.json
```

Ensure the policy allows the role `arn:aws:sts::...:assumed-role/atlantis-irsa-role/...` to perform KMS actions.

## ✅ Verifying IRSA Annotation

To verify the service account has the correct role annotated:

```bash
kubectl get serviceaccount atlantis-new -o jsonpath='{.metadata.annotations}'
```

Expected output:

```json
{ "eks.amazonaws.com/role-arn":"arn:aws:iam::<ACCOUNT_ID>:role/atlantis-irsa-role" }
```

## ⚙️ Optional: Additional Storage Classes

```bash
kubectl apply -f ./modules/helm/values/gp3-immediate.yaml
kubectl apply -f ./modules/helm/values/gp2-storageclass.yaml
```

Use these if you need dynamic volume provisioning for Atlantis.

## 📁 Repo Structure

```
.
├── main.tf
├── variables.tf
├── outputs.tf
├── modules/
│   ├── vpc/
│   ├── eks/
│   ├── iam/
│   └── helm/
└── README.md
```

## ✅ Final Checks

Confirm `aws sts get-caller-identity` shows the correct assumed role inside the `aws-cli-debug` pod.  
Use:

```bash
kubectl exec -it aws-cli-debug -- bash
```

to run commands inside the pod for debugging.

---

Happy Terraforming! 🚀

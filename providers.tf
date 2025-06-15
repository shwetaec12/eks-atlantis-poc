# Configure the AWS provider with the region specified in a variable
provider "aws" {
  region = var.aws_region
}

# Retrieve details of the EKS cluster created via a module
data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

# Retrieve authentication token for the EKS cluster (used for Kubernetes provider)
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

# Configure the Kubernetes provider using the EKS cluster details
# This enables Terraform to interact with the Kubernetes API on the EKS cluster
provider "kubernetes" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
}

# Configure the Helm provider to install Helm charts into the EKS cluster
# Uses the same EKS cluster credentials as the Kubernetes provider
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

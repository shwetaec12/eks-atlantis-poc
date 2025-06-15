module "s3_backend" {
  source      = "./modules/s3-backend"
  bucket_name = "poc-terraform-state-bucket-eucentral1"
  tags = {
    Name        = "Terraform State Bucket"
    Environment = "production"
  }
}

# Call VPC Module
module "vpc" {
  source = "./modules/vpc"

  name                 = "eks-vpc-test"
  cidr                 = var.vpc_cidr
  azs                  = ["eu-central-1a", "eu-central-1b"]
  public_subnets       = var.public_subnets
  private_subnets      = var.private_subnets
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "production"
  }
  depends_on = [module.s3_backend]
}

# Call IAM Module
module "iam" {
  source = "./modules/iam"

  oidc_url                 = "https://oidc.eks.eu-central-1.amazonaws.com/id/FF4B5D781A03AB4ECC937FCF1443EE70"
  oidc_client_id_list      = ["sts.amazonaws.com"]
  oidc_thumbprint_list     = ["9e99a48a9960b14926bb7f3b02e22da0cbed5e11"]

  eks_admin_role_name      = "eks-admin"
  node_group_role_name     = "eks-node-group"  # add this to your root module call

  atlantis_oidc_sub_condition = "oidc.eks.eu-central-1.amazonaws.com/id/FF4B5D781A03AB4ECC937FCF1443EE70:sub"
  atlantis_sa_name            = "system:serviceaccount:default:atlantis-new"
  atlantis_irsa_role_name     = "atlantis-irsa-role"
  atlantis_policy_name        = "atlantis-iam-policy"
  atlantis_policy_json        = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow"
      Action = "*"
      Resource = "*"
    }]
  })

  depends_on = [module.s3_backend]
}


# Call EKS Module
module "eks" {
  source = "./modules/eks"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnets

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["63.214.132.66/32"]

  eks_managed_node_groups = {
    default = {
      desired_size   = var.desired_node_count
      min_size       = var.desired_node_count
      max_size       = var.desired_node_count + 2
      instance_types = [var.instance_type]
      iam_role_arn   = module.iam.node_group_role_arn
    }
  }

  aws_auth_roles = [
    {
      rolearn  = module.iam.eks_admin_arn
      username = "eks-admin"
      groups   = ["system:masters"]
    },
    {
      rolearn  = module.iam.node_group_role_arn
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:bootstrappers", "system:nodes"]
    },
    {
      rolearn  = module.iam.atlantis_irsa_role_arn
      username = "atlantis"
      groups   = ["system:masters"]
    }
  ]

  aws_auth_users = [
    {
      userarn  = "arn:aws:iam::895976263444:user/shwetec12"
      username = "shwetec12"
      groups   = ["system:masters"]
    }
  ]

  tags = {
    Environment = "production"
  }
  depends_on = [module.vpc]
}

# Create Kubernetes Service Account for Atlantis
resource "kubernetes_service_account" "atlantis_sa" {
  metadata {
    name      = "atlantis-new"
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.iam.atlantis_irsa_role_arn
    }
  }
  depends_on = [module.eks]
}

# Deploy Helm chart for Atlantis
module "helm" {
  source = "./modules/helm"

  name       = "atlantis-new"
  namespace  = "default"
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  values     = [file("${path.module}/modules/helm/values/atlantis-values.yaml")]

  depends_on = [module.eks, module.s3_backend]
}
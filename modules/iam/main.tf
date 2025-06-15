resource "aws_iam_openid_connect_provider" "oidc" {
  url             = var.oidc_url
  client_id_list  = var.oidc_client_id_list
  thumbprint_list = var.oidc_thumbprint_list
}

data "aws_iam_policy_document" "eks_admin_assume" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
  }
}

resource "aws_iam_role" "eks_admin" {
  name               = var.eks_admin_role_name
  assume_role_policy = data.aws_iam_policy_document.eks_admin_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_admin_attach" {
  role       = aws_iam_role.eks_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Node Group Role and Policies
resource "aws_iam_role" "node_group" {
  name               = var.node_group_role_name
  assume_role_policy = data.aws_iam_policy_document.eks_admin_assume.json
}

resource "aws_iam_role_policy_attachment" "node_group_worker" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_group_cni" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "node_group_registry" {
  role       = aws_iam_role.node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# IRSA Role for Atlantis
data "aws_iam_policy_document" "atlantis_assume_role_policy" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = var.atlantis_oidc_sub_condition
      values   = [var.atlantis_sa_name]
    }
  }
}

resource "aws_iam_role" "atlantis_irsa_role" {
  name               = var.atlantis_irsa_role_name
  assume_role_policy = data.aws_iam_policy_document.atlantis_assume_role_policy.json
}

resource "aws_iam_role_policy" "atlantis_policy" {
  name   = var.atlantis_policy_name
  role   = aws_iam_role.atlantis_irsa_role.id
  policy = var.atlantis_policy_json
}

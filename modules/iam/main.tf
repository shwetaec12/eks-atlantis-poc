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

resource "kubernetes_service_account" "atlantis_sa" {
  metadata {
    name      = "atlantis-new"
    namespace = "default"
  }
}

# RBAC: Allow atlantis-new to patch aws-auth
resource "kubernetes_role" "aws_auth_manager" {
  metadata {
    name      = "aws-auth-manager"
    namespace = "kube-system"
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["aws-auth"]
    verbs          = ["get", "update", "patch"]
  }
}

resource "kubernetes_role_binding" "aws_auth_manager_binding" {
  metadata {
    name      = "aws-auth-manager-binding"
    namespace = "kube-system"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.aws_auth_manager.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "atlantis-new"
    namespace = "default"
  }

  depends_on = [
    kubernetes_service_account.atlantis_sa,
    kubernetes_role.aws_auth_manager
  ]
}

# ✅ RBAC: Allow atlantis-new to access serviceaccounts and secrets
# Update ClusterRole with RBAC permissions
resource "kubernetes_cluster_role" "atlantis_rbac" {
  metadata {
    name = "atlantis-access"
  }

  rule {
    api_groups = [""]
    resources  = ["secrets", "serviceaccounts"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = [
      "roles",
      "rolebindings",
      "clusterroles",
      "clusterrolebindings"
    ]
    verbs = ["get", "list", "watch"]
  }
}


resource "kubernetes_cluster_role_binding" "atlantis_rbac_binding" {
  metadata {
    name = "atlantis-access-binding"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.atlantis_rbac.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "atlantis-new"
    namespace = "default"
  }

  depends_on = [
    kubernetes_service_account.atlantis_sa,
    kubernetes_cluster_role.atlantis_rbac
  ]
}

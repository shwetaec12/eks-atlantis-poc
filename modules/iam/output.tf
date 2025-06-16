output "eks_admin_arn" {
  value = aws_iam_role.eks_admin.arn
}

output "node_group_role_arn" {
  value = aws_iam_role.node_group.arn
}

output "atlantis_irsa_role_arn" {
  value = aws_iam_role.atlantis_irsa_role.arn
}

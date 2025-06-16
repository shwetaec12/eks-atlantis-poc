variable "oidc_url" {
  type        = string
  description = "OIDC provider URL for the EKS cluster"
}

variable "oidc_client_id_list" {
  type        = list(string)
  description = "Allowed client IDs for OIDC"
}

variable "oidc_thumbprint_list" {
  type        = list(string)
  description = "Thumbprints for the OIDC provider"
}

variable "eks_admin_role_name" {
  type        = string
  description = "Name of the EKS admin IAM role"
}

variable "node_group_role_name" {
  type        = string
  description = "Name of the IAM role for EKS node group"
  default     = "eks-node-group-role"  # You can override in root if needed
}

variable "atlantis_irsa_role_name" {
  type        = string
  description = "Name of the IRSA IAM role for Atlantis"
}

variable "atlantis_oidc_sub_condition" {
  type        = string
  description = "OIDC sub condition for Atlantis IRSA role"
}

variable "atlantis_sa_name" {
  type        = string
  description = "Service account name for Atlantis"
}

variable "atlantis_policy_name" {
  type        = string
  description = "Name of the Atlantis inline policy"
}

variable "atlantis_policy_json" {
  type        = string
  description = "JSON policy document for Atlantis role"
}

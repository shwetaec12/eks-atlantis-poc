variable "oidc_url" {
  type = string
}

variable "oidc_client_id_list" {
  type = list(string)
}

variable "oidc_thumbprint_list" {
  type = list(string)
}

variable "eks_admin_role_name" {
  type = string
}

variable "atlantis_oidc_sub_condition" {
  type = string
}

variable "atlantis_sa_name" {
  type = string
}

variable "atlantis_irsa_role_name" {
  type = string
}

variable "atlantis_policy_name" {
  type = string
}

variable "atlantis_policy_json" {
  type = string
}

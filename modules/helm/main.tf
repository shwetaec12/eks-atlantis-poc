resource "helm_release" "atlantis" {
  name       = var.name
  namespace  = var.namespace

  repository = var.repository
  chart      = var.chart

  values = var.values
}

resource "helm_release" "ingress_nginx" {
  name             = local.rel_ingress_nginx
  repository       = local.repo_ingress_nginx
  chart            = "ingress-nginx"
  namespace        = local.ns_ingress_nginx
  create_namespace = true

  wait            = true
  atomic          = true
  cleanup_on_fail = true
  timeout         = 900

  depends_on = [module.eks]
}

resource "helm_release" "cert_manager" {
  name             = local.rel_cert_manager
  repository       = local.repo_cert_manager
  chart            = "cert-manager"
  namespace        = local.ns_cert_manager
  create_namespace = true

  values = [
    templatefile("${path.module}/helm-values/cert-manager.yaml", {
      role_arn = module.cert_manager_irsa.arn
    })
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true
  timeout         = 900

  depends_on = [module.eks]
}

resource "helm_release" "external_dns" {
  name             = local.rel_external_dns
  repository       = local.repo_external_dns
  chart            = "external-dns"
  namespace        = local.ns_external_dns
  create_namespace = false

  values = [
    templatefile("${path.module}/helm-values/external-dns.yaml", {
      role_arn                    = module.external_dns_irsa.arn
      region                      = var.region
      external_dns_domain_filters = local.external_dns_domain_filters
      hosted_zone_id              = var.hosted_zone_id
    })
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true
  timeout         = 900

  depends_on = [module.eks]
}

resource "helm_release" "argocd_deploy" {
  name             = local.rel_argocd
  repository       = local.repo_argocd
  chart            = "argo-cd"
  namespace        = local.ns_argocd
  create_namespace = true
  replace          = true

  values = [
    templatefile("${path.module}/helm-values/argo-cd.yaml", {
        domain = var.domain
    })
  ]

  wait            = true
  atomic          = true
  cleanup_on_fail = true
  timeout         = 900

  depends_on = [module.eks]
}
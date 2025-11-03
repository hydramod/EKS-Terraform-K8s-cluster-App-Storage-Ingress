locals {
  ns_cert_manager  = "cert-manager"
  ns_ingress_nginx = "ingress-nginx"
  ns_external_dns  = "kube-system"
  ns_argocd        = "argo-cd"

  repo_cert_manager  = "https://charts.jetstack.io"
  repo_ingress_nginx = "https://kubernetes.github.io/ingress-nginx"
  repo_external_dns  = "https://kubernetes-sigs.github.io/external-dns"
  repo_argocd        = "https://argoproj.github.io/argo-helm"

  rel_cert_manager  = "cert-manager"
  rel_ingress_nginx = "ingress-nginx"
  rel_external_dns  = "external-dns"
  rel_argocd        = "argo-cd"

  external_dns_domain_filters = (
    var.external_dns_domain_filters != null && length(var.external_dns_domain_filters) > 0
  ) ? var.external_dns_domain_filters : [var.domain]
}

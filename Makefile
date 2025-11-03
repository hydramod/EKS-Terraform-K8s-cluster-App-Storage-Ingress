# -------- Makefile (repo root) --------
SHELL := bash
.SHELLFLAGS := -o pipefail -c

# Load .env if present (export all keys)
ifneq (,$(wildcard .env))
include .env
export $(shell sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p' .env)
endif

TF_BOOTSTRAP_DIR := infra/terraform/bootstrap
TF_DIR           := infra/terraform
K8S_DIR          := k8s

# Namespaces (Terraform installs the charts into these)
INGRESS_NS := ingress-nginx
CERT_NS    := cert-manager

# Argo/app specifics (single Application file)
ARGO_NS         := argo-cd
ARGO_APP_FILE   := $(K8S_DIR)/argo-cd/guestbook-app.yaml

# Guestbook K8s objects (as in your YAMLs)
APP_NS          := default
K8S_APP_DEPLOY  := guestbook-ui
APP_CERT        := guestbook-tls
APP_INGRESS     := guestbook
APP_HOST        := guestbook.$(DOMAIN)

# Files that still live in repo
CLUSTER_ISSUER_FILE := $(K8S_DIR)/cert-manager/cluster-issuer.yaml

# Convenience (for logs only)
DOMAIN ?= $(DOMAIN)

.PHONY: help up bootstrap infra kubeconfig wait-ingress cert-manager-wait issuer \
        deploy-app wait-app status-app status dns destroy clean

help:
	@echo ""
	@echo "Targets:"
	@echo "  make up                          -> TF apply, kubeconfig, wait ingress & cert-manager, apply ClusterIssuer, deploy app"
	@echo "  make infra                       -> terraform init/plan/apply in $(TF_DIR)"
	@echo "  make kubeconfig                  -> set kubectl context from TF outputs"
	@echo "  make wait-ingress                -> wait for ingress-nginx controller + ELB hostname"
	@echo "  make cert-manager-wait           -> wait for cert-manager deployments"
	@echo "  make issuer                      -> apply k8s/cert-manager/cluster-issuer.yaml (uses .env substitutions)"
	@echo "  make deploy-app                  -> kubectl apply the Argo CD Application (guestbook)"
	@echo "  make wait-app                    -> wait for Deployment + Certificate to be ready; print curl checks"
	@echo "  make status                      -> quick cluster status (nodes, pods, svc/ing)"
	@echo "  make dns                         -> quick DNS check for $(DOMAIN)"
	@echo "  make destroy                     -> terraform destroy"
	@echo ""

# Full setup: Terraform builds VPC/EKS + Helm releases; Make then applies ClusterIssuer and deploys the app
up: bootstrap infra kubeconfig wait-ingress cert-manager-wait issuer deploy-app wait-app status

# --- Bootstrap (optional) ---
bootstrap:
	@if [ -f $(TF_BOOTSTRAP_DIR)/main.tf ]; then \
	  echo "==> Terraform bootstrap"; \
	  terraform -chdir=$(TF_BOOTSTRAP_DIR) init -upgrade; \
	  terraform -chdir=$(TF_BOOTSTRAP_DIR) apply -auto-approve; \
	else \
	  echo "==> Skipping bootstrap (no $(TF_BOOTSTRAP_DIR)/main.tf)"; \
	fi

# --- Cluster & Helm releases via Terraform ---
infra:
	@echo "==> Terraform init/plan/apply in $(TF_DIR)"
	terraform -chdir=$(TF_DIR) init -upgrade
	terraform -chdir=$(TF_DIR) plan
	terraform -chdir=$(TF_DIR) apply -auto-approve

# --- Configure kubectl from TF outputs ---
kubeconfig:
	@if ! terraform -chdir=$(TF_DIR) output -raw cluster_name >/dev/null 2>&1 || \
	    ! terraform -chdir=$(TF_DIR) output -raw region >/dev/null 2>&1; then \
	  echo "Reading cluster/region from Terraform outputs..."; \
	fi
	aws eks update-kubeconfig --name "$$(terraform -chdir=$(TF_DIR) output -raw cluster_name)" \
	  --region "$$(terraform -chdir=$(TF_DIR) output -raw region)" \
	  --alias "$$(terraform -chdir=$(TF_DIR) output -raw cluster_name)"
	kubectl config use-context "$$(terraform -chdir=$(TF_DIR) output -raw cluster_name)"

# --- Wait for ingress-nginx to be ready and expose an ELB ---
wait-ingress:
	@echo "==> Waiting for ingress controller rollout"
	kubectl -n $(INGRESS_NS) rollout status deploy/ingress-nginx-controller --timeout=5m
	@echo "==> Waiting for $(INGRESS_NS)/ingress-nginx-controller LoadBalancer hostname..."
	@i=0; \
	while [ $$i -lt 60 ]; do \
	  H=$$(kubectl -n $(INGRESS_NS) get svc ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null); \
	  if [ -n "$$H" ]; then echo "$$H" | tee .ingress_hostname; echo "ELB hostname: $$H"; break; fi; \
	  sleep 10; i=$$((i+1)); \
	done
	@test -s .ingress_hostname

# --- Wait for cert-manager (Terraform installed it) ---
cert-manager-wait:
	@echo "==> Waiting for cert-manager deployments"
	kubectl -n $(CERT_NS) rollout status deploy/cert-manager --timeout=5m
	kubectl -n $(CERT_NS) rollout status deploy/cert-manager-webhook --timeout=5m
	kubectl -n $(CERT_NS) rollout status deploy/cert-manager-cainjector --timeout=5m

# --- Apply ClusterIssuer (uses .env vars ACME_EMAIL/DOMAIN/REGION/HOSTED_ZONE_ID) ---
issuer:
	@if [ ! -f "$(CLUSTER_ISSUER_FILE)" ]; then \
	  echo "ERROR: $(CLUSTER_ISSUER_FILE) not found."; exit 1; \
	fi
	@if [ -z "$(ACME_EMAIL)" ] || [ -z "$(DOMAIN)" ] || [ -z "$(REGION)" ] || [ -z "$(HOSTED_ZONE_ID)" ]; then \
	  echo "ERROR: Missing one of ACME_EMAIL, DOMAIN, REGION, HOSTED_ZONE_ID (check .env)."; exit 1; \
	fi
	@echo "==> Applying ClusterIssuer for $(DOMAIN) with ACME email $(ACME_EMAIL)"
	sed -e "s|\$${ACME_EMAIL}|$(ACME_EMAIL)|g" \
	    -e "s|\$${DOMAIN}|$(DOMAIN)|g" \
	    -e "s|\$${REGION}|$(REGION)|g" \
	    -e "s|\$${HOSTED_ZONE_ID}|$(HOSTED_ZONE_ID)|g" \
	    "$(CLUSTER_ISSUER_FILE)" | kubectl apply -f -

# --- Deploy the Argo CD Application for the app (single file) ---
deploy-app:
	@echo "==> Applying Argo CD Application: $(ARGO_APP_FILE)"
	kubectl -n $(ARGO_NS) apply -f "$(ARGO_APP_FILE)"

# --- Wait for the app to be usable over HTTPS ---
wait-app:
	@echo "==> Waiting for Deployment/Certificate"
	-kubectl -n $(APP_NS) rollout status deploy/$(K8S_APP_DEPLOY) --timeout=10m
	-kubectl -n $(APP_NS) wait --for=condition=Ready certificate/$(APP_CERT) --timeout=10m
	@echo "==> Ingress status"
	-kubectl -n $(APP_NS) get ingress $(APP_INGRESS) -o wide
	@echo "==> curl check (HTTP->HTTPS)"
	-@curl -sI http://$(APP_HOST) | sed -n '1,3p' || true
	@echo "==> TLS check"
	-@curl -skI https://$(APP_HOST) | sed -n '1,3p' || true

# --- Convenience status ---
status:
	@echo "==> kubectl context"; kubectl config current-context
	@echo "==> Nodes"; kubectl get nodes -o wide
	@echo "==> kube-system"; kubectl -n kube-system get pods
	@echo "==> cert-manager"; kubectl -n $(CERT_NS) get pods || true
	@echo "==> external-dns"; kubectl -n kube-system get deploy,po -l app.kubernetes.io/name=external-dns || true
	@echo "==> ingress svc"; kubectl -n $(INGRESS_NS) get svc ingress-nginx-controller -o wide || true
	@echo "==> certificates"; kubectl get clusterissuer,certificate,challenge,order --all-namespaces || true

# Optional DNS check
dns:
	@echo "==> Domain: $(DOMAIN)"
	@if command -v nslookup >/dev/null 2>&1; then nslookup $(DOMAIN) || true; else echo "nslookup not found (optional)"; fi

# --- Tear down controlled by Terraform ---
destroy:
	@echo "==> Terraform destroy in $(TF_DIR)"
	-terraform -chdir=$(TF_DIR) destroy -auto-approve

clean:
	-@rm -f .ingress_hostname

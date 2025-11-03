# EKS + Terraform + Ingress + TLS + Argo CD — End‑to‑End Demo

Spin up an **Amazon EKS** cluster with Terraform, install core add‑ons (Ingress‑NGINX, cert‑manager, external‑dns, Argo CD), and deploy a sample **Guestbook** app with HTTPS and DNS via Route 53 — all orchestrated through a simple `Makefile`.

> **Highlights**
>
> * **IaC**: VPC, EKS, IRSA with Terraform
> * **Add‑ons via Helm**: Ingress‑NGINX, cert‑manager, external‑dns, Argo CD
> * **DNS + TLS**: Route 53 records managed by external‑dns; ACME via cert‑manager (Let’s Encrypt)
> * **GitOps**: Argo CD deploys the `guestbook` app manifests in `k8s/apps/guestbook`
> * **1‑command bring‑up**: `make up`

---

## Repository Structure

```
📦EKS-Terraform-K8s-cluster-App-Storage-Ingress
 ┣ 📂infra
 ┃ ┗ 📂terraform
 ┃ ┃ ┣ 📂bootstrap                  # Creates S3 bucket for Terraform remote state (local state here only)
 ┃ ┃ ┃ ┣ 📜main.tf
 ┃ ┃ ┃ ┣ 📜outputs.tf
 ┃ ┃ ┃ ┣ 📜terraform.tfvars
 ┃ ┃ ┃ ┗ 📜variables.tf
 ┃ ┃ ┣ 📂helm-values                 # Values passed to Helm charts by Terraform
 ┃ ┃ ┃ ┣ 📜argo-cd.yaml              # ingress for argocd.${DOMAIN}, TLS via ClusterIssuer
 ┃ ┃ ┃ ┣ 📜cert-manager.yaml         # IRSA role annotation templated in
 ┃ ┃ ┃ ┗ 📜external-dns.yaml         # IRSA + domain filters + region templated in
 ┃ ┃ ┣ 📜data.tf
 ┃ ┃ ┣ 📜eks.tf                      # EKS cluster/node groups
 ┃ ┃ ┣ 📜helm.tf                     # Helm releases (ingress-nginx, cert-manager, external-dns, argo-cd)
 ┃ ┃ ┣ 📜irsa.tf                     # IAM Roles for Service Accounts (cert-manager, external-dns)
 ┃ ┃ ┣ 📜locals.tf
 ┃ ┃ ┣ 📜outputs.tf                  # At least: region, cluster_name, etc.
 ┃ ┃ ┣ 📜provider.tf
 ┃ ┃ ┣ 📜terraform.tfvars            # Main TF variables for this environment
 ┃ ┃ ┣ 📜variables.tf
 ┃ ┃ ┗ 📜vpc.tf                      # VPC/Subnets/IGW/NAT/etc.
 ┣ 📂k8s
 ┃ ┣ 📂apps
 ┃ ┃ ┗ 📂guestbook                   # Sample app: Deployment/Service/Ingress + TLS
 ┃ ┃   ┣ 📜deployment.yaml
 ┃ ┃   ┣ 📜ingress.yaml
 ┃ ┃   ┗ 📜service.yaml
 ┃ ┣ 📂argo-cd
 ┃ ┃ ┗ 📜guestbook-app.yaml          # Argo CD Application pointing to k8s/apps/guestbook
 ┃ ┗ 📂cert-manager
 ┃   ┗ 📜cluster-issuer.yaml         # ACME (Let’s Encrypt) ClusterIssuer (DNS01 via Route 53)
 ┣ 📜.env                            # Environment values consumed by Makefile
 ┣ 📜.gitignore
 ┣ 📜Makefile                        # Orchestration for bring‑up / deploy / checks / teardown
 ┗ 📜README.md
```

---

## Prerequisites

* **AWS account** with a **public Route 53 hosted zone** for your domain (e.g. `example.com`).
* **Credentials** with permissions to create VPC, EKS, IAM, Route 53 records, and S3.
* **CLI tools**: `terraform` (≥ **1.13.4**), `kubectl`, `awscli`, `helm`, `jq`, `sed`, `bash`.
* Optionally set an AWS profile: `export AWS_PROFILE=your-profile`.

> The **bootstrap** step uses local TF state to create a remote‑state **S3 bucket** (required provider `hashicorp/aws` **6.18.0**, region `us-east-1`).

---

## Quick Start (TL;DR)

1. **Configure `.env`** (see below). Ensure your Route 53 hosted zone exists and is authoritative.

2. **One‑shot bring‑up**:

   ```bash
   make up
   ```

   This will:

   * (Optionally) create the **remote state S3** bucket under `infra/terraform/bootstrap`
   * `terraform apply` the main infra (VPC, EKS, IRSA, Helm add‑ons)
   * Set **kubeconfig** to your EKS cluster context
   * Wait for **Ingress‑NGINX** & **cert-manager** to become ready
   * Apply the **ClusterIssuer** (Let’s Encrypt → Route 53 DNS01)
   * Deploy the **guestbook** app via **Argo CD**
   * Perform health checks (ingress + HTTPS)

3. **Check status**:

   ```bash
   make status
   ```

4. **Destroy** when done:

   ```bash
   make destroy
   ```

---

## Environment Configuration (`.env`)

Create a `.env` file in repo root; it is auto‑loaded by the `Makefile`.

```env
# Required for ClusterIssuer substitution and convenience targets
ACME_EMAIL=you@example.com
DOMAIN=example.com                # Your Route 53 public hosted zone
REGION=us-east-1                  # Must match your AWS region
HOSTED_ZONE_ID=ZABCDEFGHIJKL      # Route 53 hosted zone ID for DOMAIN

# Optional
AWS_PROFILE=default
```

> `Makefile` expands these into `k8s/cert-manager/cluster-issuer.yaml` at apply time and uses them for log messages & curl checks. The **TLS endpoints** will be:
>
> * **Argo CD**: `https://argocd.${DOMAIN}`
> * **Guestbook**: `https://guestbook.${DOMAIN}`

---

## What Terraform Provisions

### Networking & Cluster

* **VPC** with public/private subnets
* **EKS** cluster (plus node groups)

### IAM / IRSA

* **IAM OIDC provider** for the cluster
* **IRSA roles** for:

  * **cert-manager** → allow Route 53 DNS01 challenge changes
  * **external-dns** → manage DNS records in your hosted zone(s)

### Helm Releases (via Terraform)

* **Ingress‑NGINX** (namespace: `ingress-nginx`)
* **cert-manager** (namespace: `cert-manager`)

  * Helm values file: `infra/terraform/helm-values/cert-manager.yaml`
  * Injects `serviceAccount.annotations.eks.amazonaws.com/role-arn` with the IRSA role
* **external-dns** (namespace typically `kube-system`)

  * Helm values file: `infra/terraform/helm-values/external-dns.yaml`
  * Injects `region`, IRSA `role-arn`, and `domainFilters` (via Terraform variables)
* **Argo CD** (namespace: `argo-cd`)

  * Helm values file: `infra/terraform/helm-values/argo-cd.yaml`
  * Exposes `argocd.${DOMAIN}` via Ingress & TLS (`letsencrypt-production` ClusterIssuer)

> Values files are **templated** by Terraform to pass environment‑specific values such as `${region}`, `${role_arn}`, `${domain}`, and `external_dns_domain_filters`.

---

## GitOps Application (Guestbook)

* **Argo CD Application**: `k8s/argo-cd/guestbook-app.yaml` points to the manifests in `k8s/apps/guestbook`.
* The **Guestbook** app includes:

  * `Deployment` (`guestbook-ui`), `Service`
  * `Ingress` → host `guestbook.${DOMAIN}` with TLS secret `guestbook-tls`
* **cert-manager** issues a TLS certificate using the `ClusterIssuer` applied by `make issuer`.

---

## Makefile Targets

> Run `make help` to see this list at any time.

* **`make up`** – Full flow: bootstrap (if present) → infra → kubeconfig → wait ingress & cert-manager → apply ClusterIssuer → deploy app → wait & verify
* **`make infra`** – `terraform init/plan/apply` in `infra/terraform`
* **`make kubeconfig`** – Configure kubectl from Terraform outputs: `cluster_name`, `region`
* **`make wait-ingress`** – Wait for Ingress‑NGINX controller rollout and capture ELB hostname to `.ingress_hostname`
* **`make cert-manager-wait`** – Wait for cert-manager deployments to be ready
* **`make issuer`** – Apply `k8s/cert-manager/cluster-issuer.yaml` with `.env` substitutions (ACME email, domain, region, hosted zone id)
* **`make deploy-app`** – Apply the Argo CD Application manifest
* **`make wait-app`** – Wait for the app `Deployment` + `Certificate`, then run HTTP→HTTPS and TLS curl checks
* **`make status`** – Quick cluster status (nodes, pods, services, ingress, certs, external‑dns)
* **`make dns`** – Optional `nslookup` for `$(DOMAIN)`
* **`make destroy`** – `terraform destroy` for `infra/terraform`
* **`make clean`** – Remove `.ingress_hostname`

---

## Step‑by‑Step Bring‑Up

> If using the **one‑shot** `make up`, you can skip these and let the Makefile do it for you.

1. **Bootstrap remote state (optional)**

   ```bash
   cd infra/terraform/bootstrap
   terraform init -upgrade
   terraform apply -auto-approve
   ```

   * Creates S3 bucket `bucket_name` (default example: `eks-demo-alistechlab`, region `us-east-1`)
   * This folder **keeps local state**; do not point it at the bucket it creates

2. **Provision infra**

   ```bash
   terraform -chdir=infra/terraform init -upgrade
   terraform -chdir=infra/terraform plan
   terraform -chdir=infra/terraform apply -auto-approve
   ```

3. **Configure kubectl**

   ```bash
   aws eks update-kubeconfig \
     --name  "$(terraform -chdir=infra/terraform output -raw cluster_name)" \
     --region "$(terraform -chdir=infra/terraform output -raw region)" \
     --alias  "$(terraform -chdir=infra/terraform output -raw cluster_name)"
   kubectl config use-context "$(terraform -chdir=infra/terraform output -raw cluster_name)"
   ```

4. **Wait for add‑ons** (Ingress, cert-manager)

   ```bash
   kubectl -n ingress-nginx rollout status deploy/ingress-nginx-controller --timeout=5m
   kubectl -n cert-manager rollout status deploy/cert-manager --timeout=5m
   kubectl -n cert-manager rollout status deploy/cert-manager-webhook --timeout=5m
   kubectl -n cert-manager rollout status deploy/cert-manager-cainjector --timeout=5m
   ```

5. **Apply ClusterIssuer** (Let’s Encrypt, Route 53 DNS01)

   ```bash
   # Uses .env substitutions for ACME_EMAIL, DOMAIN, REGION, HOSTED_ZONE_ID
   sed -e "s|\${ACME_EMAIL}|$ACME_EMAIL|g" \
       -e "s|\${DOMAIN}|$DOMAIN|g" \
       -e "s|\${REGION}|$REGION|g" \
       -e "s|\${HOSTED_ZONE_ID}|$HOSTED_ZONE_ID|g" \
       k8s/cert-manager/cluster-issuer.yaml | kubectl apply -f -
   ```

6. **Deploy GitOps application (Argo CD Application)**

   ```bash
   kubectl -n argo-cd apply -f k8s/argo-cd/guestbook-app.yaml
   ```

7. **Check ingress & TLS**

   ```bash
   kubectl -n default get ingress guestbook -o wide
   curl -sI http://guestbook.$DOMAIN | sed -n '1,3p'   # expect redirect to HTTPS
   curl -skI https://guestbook.$DOMAIN | sed -n '1,3p' # check 200/301 response
   ```

---

## Accessing Argo CD

* URL: `https://argocd.${DOMAIN}`
* Initial admin password (Helm default):

  ```bash
  kubectl -n argo-cd get secret argocd-initial-admin-secret \
    -o jsonpath='{.data.password}' | base64 -d; echo
  ```
* The supplied `argo-cd.yaml` enables an Ingress (class `nginx`) and annotates it for TLS using the `letsencrypt-production` ClusterIssuer.

---

## Variables & Outputs

### Bootstrap module (`infra/terraform/bootstrap`)

* **Terraform**: `required_version = "1.13.4"`
* **AWS provider**: `hashicorp/aws` `6.18.0`
* **Region**: `us-east-1`
* **Variables**:

  * `bucket_name` *(string, required)* — S3 bucket for remote state (default example `eks-demo-alistechlab`)
* **Outputs**:

  * `bucket_name`

### Main infra (`infra/terraform`)

* **Expected outputs** (consumed by `make kubeconfig`):

  * `cluster_name`
  * `region`
* **Helm values templating** (Terraform → values files):

  * `cert-manager.yaml`: `${role_arn}` → IRSA role for cert-manager
  * `external-dns.yaml`: `${region}`, `${role_arn}`, `external_dns_domain_filters`
  * `argo-cd.yaml`: `${domain}`

---

## DNS & Certificates — How it Comes Together

1. **Ingress‑NGINX** exposes a LoadBalancer Service → AWS ELB hostname (captured in `.ingress_hostname`).
2. **external‑dns** watches Services/Ingresses, then **creates Route 53 records** (restricted by `domainFilters`).
3. **cert‑manager** requests ACME certs using **DNS‑01** solver against Route 53, assuming the IRSA role.
4. **Your app** and **Argo CD** Ingresses terminate TLS using those certificates.

---

## Troubleshooting

* **ELB hostname never appears**

  * `kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide`
  * Ensure the cluster has public subnets tagged for LoadBalancer and that your AWS account quota allows it.

* **No DNS records created**

  * Check `external-dns` logs; confirm IRSA role permissions and correct `domainFilters` including your `${DOMAIN}`.

* **Certificates stuck in `Pending`**

  * `kubectl describe challenge -A` and `kubectl describe order -A`
  * Confirm Route 53 hosted zone is public and authoritative; ensure `HOSTED_ZONE_ID` matches `DOMAIN`.

* **EKS AMI/Provider mismatch**

  * If you see issues with node AMIs or version skew, set managed node group `ami_type = "AL2023_x86_64_STANDARD"` and ensure Kubernetes provider compatibility with your EKS version.

* **Argo CD login fails / certificate not ready**

  * Wait for `argocd-server-tls` secret; verify ClusterIssuer exists and is `Ready`.

* **Makefile env missing**

  * `make issuer` requires `ACME_EMAIL`, `DOMAIN`, `REGION`, `HOSTED_ZONE_ID`. Verify `.env`.

---

## Troubleshooting — project‑specific learnings

Below are issues we've actually hit (plus a few likely ones) and how to diagnose/fix quickly.

### 1) kubeconfig/context drift

**Symptom**: `You must be logged in to the server (Unauthorized)` or wrong cluster.

**Fix**:

```bash
make kubeconfig
kubectl config current-context
kubectl get nodes -o wide
```

If outputs aren’t present yet, re‑run `make infra` first.

### 2) Ingress‑NGINX `EXTERNAL-IP` pending

**Symptom**: `kubectl -n ingress-nginx get svc ingress-nginx-controller` shows `pending` for a long time.

**Checks**:

* Subnet tags exist: `kubernetes.io/role/elb = 1` and `kubernetes.io/cluster/<cluster-name> = shared` on **public** subnets.
* AWS account has Load Balancer quota.

**Commands**:

```bash
kubectl -n ingress-nginx get svc ingress-nginx-controller -o wide
cat .ingress_hostname || true
```

### 3) external‑dns not creating records

**Symptoms**: No Route 53 records; logs show `No zones matched`, `AccessDenied`, or continuous `Desired change: CREATE` without effect.

**Fix**:

* Ensure `.env` **DOMAIN** matches your hosted zone and `HOSTED_ZONE_ID` is correct.
* `external_dns_domain_filters` include your domain (and subdomains) in Terraform.
* IRSA role attached & service account annotated.

**Logs**:

```bash
kubectl -n kube-system logs deploy/external-dns | egrep 'No zones matched|AccessDenied|Desired change|Throttling' || true
```

### 4) cert‑manager DNS‑01 challenge stuck `Pending`

**Symptoms**: `kubectl get certificate,order,challenge -A` shows `Pending/Failed` with Route 53 messages.

**Fix**:

* Run `make issuer` after add‑ons are ready so the **ClusterIssuer** exists.
* Verify IRSA permissions for Route 53 (list/change record sets).
* Use **staging** issuer first if you suspect Let’s Encrypt rate limits.

**Debug**:

```bash
kubectl describe challenge -A | sed -n '1,120p'
kubectl describe order -A | sed -n '1,120p'
```

### 5) Argo CD Ingress/TLS issues

**Symptoms**: `argocd.${DOMAIN}` 404/timeout or invalid cert.

**Fix**:

* Confirm Helm values set host and `ingressClassName: nginx` (or annotation `kubernetes.io/ingress.class: nginx`).
* Wait for certificate secret to appear; then:

```bash
kubectl -n argo-cd get ingress,svc,pods
kubectl -n argo-cd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

### 6) Namespace / Application mis‑wiring

**Symptoms**: Argo CD shows `OutOfSync` or creates resources in the wrong namespace.

**Fix**: Ensure `k8s/argo-cd/guestbook-app.yaml` `destination.namespace` and the manifests’ `metadata.namespace` are aligned (default to `default`).

### 7) IRSA / OIDC trust problems

**Symptoms**: `AccessDenied` from AWS APIs in cert‑manager/external‑dns despite roles.

**Checks**:

```bash
# OIDC issuer on the cluster
aws eks describe-cluster --name "$(terraform -chdir=infra/terraform output -raw cluster_name)" \
  --region "$(terraform -chdir=infra/terraform output -raw region)" \
  --query 'cluster.identity.oidc.issuer'

# ServiceAccount annotations
kubectl -n cert-manager get sa cert-manager -o yaml | grep eks.amazonaws.com/role-arn -n
kubectl -n kube-system get sa external-dns -o yaml | grep eks.amazonaws.com/role-arn -n
```

Ensure the IAM role trust policy allows the cluster OIDC provider and audience `sts.amazonaws.com`.

### 8) Terraform backend / lock issues

**Symptoms**: `Error acquiring the state lock` or backend not configured after bootstrap.

**Fix**:

* In **main** Terraform (`infra/terraform`), configure the `backend "s3"` to the bucket created by bootstrap.
* If a lock is stuck (with DynamoDB), use `terraform force-unlock <id>`.

### 9) Helm CRD ordering/timeouts

**Symptoms**: Helm install/upgrade fails on CRDs (esp. cert‑manager) or hits timeouts.

**Fix**: Use chart settings that install CRDs (cert‑manager chart supports `installCRDs: true`), and consider longer timeouts/atomic installs in Terraform `helm_release`.

### 10) Ingress class/annotation mismatch

**Symptoms**: Ingress admitted by a different controller or not at all.

**Fix**: Ensure **either** `ingressClassName: nginx` **or** the legacy annotation `kubernetes.io/ingress.class: nginx` is present and matches your controller.

### 11) DNS propagation / testing without DNS

**Tip**: While waiting for DNS, test with the raw ELB hostname saved by `make wait-ingress`:

```bash
ELB=$(cat .ingress_hostname)
curl -skI https://$ELB | sed -n '1,3p'
```

### 12) HTTP→HTTPS redirect loops / 308s

**Symptoms**: `curl -I` shows repeated 30x.

**Fix**: Ensure your app/service doesn’t also enforce redirects conflicting with the Ingress annotations and that the TLS hostnames match `guestbook.${DOMAIN}`.

### 13) Makefile env not set

**Symptoms**: `make issuer` errors about missing `ACME_EMAIL`, `DOMAIN`, `REGION`, `HOSTED_ZONE_ID`.

**Fix**: Create/populate `.env` in repo root. Re-run `make up` or `make issuer`.

---

## Security & Cost Notes

* This stack creates billable resources (EKS, Load Balancers, NAT, Route 53, etc.). **Destroy** when not in use.
* Lock down IRSA roles to the specific hosted zone and least privileges required by cert‑manager and external‑dns.
* For production, harden the S3 remote state bucket: enable versioning, encryption, and public access blocks.

---

## Cleanup

```bash
make destroy      # Destroys infra provisioned in infra/terraform
# If you created a bootstrap S3 bucket and want to remove it too, empty and destroy it from infra/terraform/bootstrap
```

---

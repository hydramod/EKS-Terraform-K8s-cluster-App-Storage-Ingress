# EKS-Terraform-K8s-cluster-App-Storage-Ingress

## Comprehensive AWS EKS Cluster Deployment with Terraform, Argo CD, and Full Application Stack

This repository provides a complete, production-ready infrastructure-as-code (IaC) solution for deploying an Amazon EKS (Elastic Kubernetes Service) cluster on AWS, along with a comprehensive application stack managed by Argo CD. The setup is designed for modern cloud-native applications, featuring automated TLS, DNS management, and persistent storage.

### Key Features

The solution orchestrates the deployment of the following components:

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| **Infrastructure** | **Terraform** (`infra/terraform`) | Provisions the VPC, EKS cluster, and necessary IAM roles (IRSA). |
| **Cluster Management** | **Argo CD** (via Helm) | Deploys and manages the cluster add-ons and applications using GitOps principles. |
| **Ingress Controller** | **NGINX Ingress Controller** (via Helm) | Manages external access to services within the cluster. |
| **TLS/Certificates** | **cert-manager** (via Helm) | Automates the issuance and renewal of TLS certificates from Let's Encrypt using the Route53 DNS01 challenge. |
| **DNS Management** | **ExternalDNS** (via Helm) | Automatically creates and manages Route53 records for Kubernetes Ingress resources. |
| **Persistent Storage** | **AWS EBS gp3** | Provides a default StorageClass for high-performance, cost-effective persistent volumes. |
| **Sample Application** | **Guestbook App** (`k8s/apps/guestbook`) | A simple, HTTPS-enabled echo application deployed via Argo CD to validate the entire stack. |

### Repository Structure

The project is organized into two main directories: `infra` for Terraform code and `k8s` for Kubernetes manifests.

```
.
├── infra/
│   └── terraform/
│       ├── bootstrap/             # Scripts for initial setup (e.g., kubeconfig)
│       ├── helm-values/           # Helm value files for cluster add-ons
│       ├── eks.tf                 # EKS cluster and node group definition
│       ├── helm.tf                # Helm releases for cluster add-ons (NGINX, cert-manager, ExternalDNS)
│       ├── irsa.tf                # IAM Roles for Service Accounts (IRSA)
│       ├── locals.tf              # Local variables
│       ├── outputs.tf             # Outputs like EKS endpoint and kubeconfig
│       ├── provider.tf            # AWS and Kubernetes providers configuration
│       ├── variables.tf           # Input variables for customization
│       └── vpc.tf                 # VPC and networking definition
└── k8s/
    ├── apps/
    │   └── guestbook/             # Kubernetes manifests for the sample application
    │       ├── deployment.yaml    # Guestbook Deployment
    │       ├── ingress.yaml       # Guestbook Ingress with cert-manager annotations
    │       └── service.yaml       # Guestbook Service
    ├── argo-cd/
    │   └── guestbook-app.yaml     # Argo CD Application manifest for the Guestbook app
    └── cert-manager/
        └── cluster-issuer.yaml    # ClusterIssuer configuration for Let's Encrypt (DNS01)
```

### Deployment Flow

The deployment follows a two-stage GitOps approach:

1.  **Terraform Deployment (Infrastructure):**
    *   **VPC & EKS:** Terraform provisions the AWS VPC, Subnets, and the EKS cluster itself (`vpc.tf`, `eks.tf`).
    *   **Add-ons (Helm):** Terraform uses the `helm_release` resource to deploy critical cluster add-ons:
        *   **NGINX Ingress Controller**
        *   **cert-manager**
        *   **ExternalDNS**
        *   **Argo CD**
    *   **IRSA:** IAM Roles for Service Accounts are created for `cert-manager` and `ExternalDNS` to interact with AWS Route53.

2.  **Argo CD Deployment (Applications):**
    *   Once Argo CD is deployed by Terraform, it is configured to monitor this repository.
    *   The `k8s/argo-cd/guestbook-app.yaml` manifest defines an Argo CD `Application` resource.
    *   This application points to the `k8s/apps/guestbook` path in this repository, ensuring the sample application (Deployment, Service, Ingress) is automatically synchronized and deployed to the EKS cluster.

### Prerequisites

To deploy this infrastructure, you will need:

*   **AWS Account:** Configured with appropriate credentials.
*   **Terraform:** Installed locally (version 1.0+ recommended).
*   **kubectl:** Installed locally.
*   **Domain Name:** A registered domain name managed by AWS Route53.
*   **Environment Variables:** The deployment relies on several variables defined in the `.env` file and consumed by `variables.tf`.

### Configuration and Customization

The primary configuration points are located in `infra/terraform/variables.tf` and the `.env` file.

| Variable | Description | Default Value | Customization Notes |
| :--- | :--- | :--- | :--- |
| `name` | Base name for all EKS resources. | `demo-eks` | Change this to a unique identifier for your environment. |
| `region` | AWS region for deployment. | `us-east-1` | Select your desired AWS region. |
| `cluster_version` | Kubernetes version for EKS. | `1.34` | Ensure this is a supported EKS version. |
| `node_desired_size` | Desired number of worker nodes. | `2` | Scale up or down based on your workload needs. |
| `node_instance_types` | Instance type for EKS managed node group. | `t3.large` | Adjust for performance and cost optimization. |
| `ingress_hostname` | The hostname for the sample application. | `guestbook.alistechlab.click` | **CRITICAL:** Must be a subdomain of your Route53-managed domain. |
| `acme_email` | Email for Let's Encrypt registration. | `${ACME_EMAIL}` | Set this in your `.env` file. |
| `hosted_zone_id` | Route53 Hosted Zone ID for ExternalDNS. | `${HOSTED_ZONE_ID}` | Set this in your `.env` file. |

### Deployment Steps

1.  **Clone the Repository:**
    ```bash
    git clone https://github.com/hydramod/EKS-Terraform-K8s-cluster-App-Storage-Ingress.git
    cd EKS-Terraform-K8s-cluster-App-Storage-Ingress/infra/terraform
    ```

2.  **Configure Environment Variables:**
    Create a `.env` file in the `infra/terraform` directory and populate it with your specific values.

    ```bash
    # .env example
    export ACME_EMAIL="your-email@example.com"
    export HOSTED_ZONE_ID="Z0123456789ABCDEF"
    ```

3.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

4.  **Review and Apply:**
    Review the plan and apply the changes to provision the infrastructure and core services.

    ```bash
    terraform plan
    terraform apply -auto-approve
    ```

5.  **Access the Cluster:**
    After a successful apply, Terraform will output the command to configure `kubectl`.

    ```bash
    # Example output:
    # Run this command to configure kubectl:
    # aws eks update-kubeconfig --name demo-eks --region us-east-1
    ```

6.  **Verify Argo CD and Application Deployment:**
    *   Check the Argo CD application status:
        ```bash
        kubectl get application guestbook -n argo-cd
        ```
    *   Wait for the application to synchronize and become healthy.
    *   Access the sample application via the hostname you configured (e.g., `https://guestbook.yourdomain.com`).

### Cleanup

To destroy all provisioned resources and avoid incurring further AWS costs, run the following command from the `infra/terraform` directory:

```bash
terraform destroy -auto-approve
```

---
*README generated by Manus AI based on repository analysis.*
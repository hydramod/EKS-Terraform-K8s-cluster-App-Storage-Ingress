variable "name" {
  description = "Base name for the EKS cluster and resources"
  type        = string
  default     = "demo-eks"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.34"
}

variable "node_desired_size" {
  description = "Desired node count"
  type        = number
  default     = 2
}

variable "node_min_size" {
  description = "Minimum node count"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum node count"
  type        = number
  default     = 4
}

variable "node_instance_types" {
  description = "Instance types for EKS managed node group"
  type        = list(string)
  default     = ["t3a.large", "t3.large"]
}

variable "enable_endpoint_public_access" {
  description = "Whether the EKS API server should be publicly accessible"
  type        = bool
  default     = true
}

variable "extra_admin_cidrs" {
  description = "Other CIDRs to allow (office/VPN/CI)."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.extra_admin_cidrs : (
        can(cidrnetmask(cidr)) && !contains([
          "192.0.2.0/24",
          "198.51.100.0/24",
          "203.0.113.0/24"
        ], cidr)
      )
    ])

    error_message = "admin_cidrs must contain valid IPv4 CIDR blocks and cannot include documentation/test networks like 203.0.113.0/24."
  }
}

variable "domain" {
  description = "Base domain"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route53 Hosted Zone ID"
  type        = string
  sensitive   = true
}

variable "external_dns_domain_filters" {
  description = "Domains ExternalDNS is allowed to manage"
  type        = list(string)
  default     = null
}

variable "external_dns_txt_owner_id" {
  description = "ExternalDNS TXT registry owner ID"
  type        = string
  default     = null
}

variable "acme_email" {
  description = "Email address for Let's Encrypt ACME registration"
  type        = string
  sensitive   = true
}

variable "bucket" {
  description = "S3 Bucket name"
  type        = string
}

variable "key" {
  description = "tfstate key"
  type        = string
}

variable "dynamodb_table" {
  description = "DynamoDB Table name"
  type        = string
}
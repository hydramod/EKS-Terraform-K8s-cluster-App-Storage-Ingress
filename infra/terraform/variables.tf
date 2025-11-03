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

variable "node_instance_types" {
  description = "Instance types for EKS managed node group"
  type        = string
  default     = "t3.large"
}

variable "admin_cidrs" {
  description = "List of CIDR blocks that can access the EKS cluster API"
  type        = list(string)
  default     = ["0.0.0.0/0"]
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


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
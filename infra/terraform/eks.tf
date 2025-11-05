module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "21.8.0"

  name               = var.name
  kubernetes_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  enable_cluster_creator_admin_permissions = true
  endpoint_public_access                   = var.enable_endpoint_public_access
  endpoint_private_access                  = true
  endpoint_public_access_cidrs             = local.admin_cidrs

  addons = {
    coredns    = {}
    kube-proxy = {}
    vpc-cni = {
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.arn
    }
    eks-pod-identity-agent = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_irsa.arn
      before_compute           = false
    }
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      desired_size   = var.node_desired_size
      min_size       = var.node_min_size
      max_size       = var.node_max_size
    }
  }
}
module "eks-auto" {
  source  = "terraform-aws-modules/eks/aws"

  version = "~> 20.0"

  cluster_name    = "sample-eks-automode-cluster"
  cluster_version = "1.31"
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = local.filtered_subnets
}
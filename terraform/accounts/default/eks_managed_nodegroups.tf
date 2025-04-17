/*
The following 2 data resources are used get around the fact that we have to wait
for the EKS cluster to be initialised before we can attempt to authenticate.
*/

data "aws_eks_cluster" "default" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "default" {
  name = module.eks.cluster_name

  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.default.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.default.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.default.token
}

module "vpc_cni_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "VPC-CNI-IRSA"
  attach_vpc_cni_policy = true
  vpc_cni_enable_ipv4   = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-node"]
    }
  }
}

// We want to filter out subnets that cannot be used to create the control plane in.
// For example, us-east-1e is currently not allowed.

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [module.vpc.vpc_id]
  }
}

data "aws_subnet" "private_subnets" {
  count = length(module.vpc.private_subnets)

  id = module.vpc.private_subnets[count.index]
}


locals {
  excluded_azs = ["us-east-1e"]
  filtered_subnets = [
    for subnet in data.aws_subnet.private_subnets : subnet.id
    if !contains(local.excluded_azs, subnet.availability_zone)
  ]
}

// Create IAM roles for various EKS addons
//
module "ebs_csi_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name_prefix      = "EBS-CSI-IRSA"
  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }
}

module "eks" {
  depends_on = [module.vpc]

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "sample-eks-cluster"
  cluster_version = "1.32"

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access  = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
    vpc-cni = {
      most_recent              = true
      before_compute           = true
      service_account_role_arn = module.vpc_cni_irsa.iam_role_arn
      configuration_values = jsonencode({
        env = {
          # Reference docs https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
          ENABLE_PREFIX_DELEGATION = "true"
          WARM_PREFIX_TARGET       = "1"
        }
      })
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.ebs_csi_irsa.iam_role_arn
    }
    amazon-cloudwatch-observability = {
      most_recent = true
    }
  }

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description = "Allow kubectl access within VPC"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = ["10.0.0.0/16"]
    }
  }

  node_security_group_additional_rules = {
    ingress_nodes_ssh_ports_tcp = {
      description = "Allow SSH access within VPC"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = ["10.0.0.0/16"]
    }
  }

  vpc_id = module.vpc.vpc_id

  subnet_ids = local.filtered_subnets

  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }

  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  cloudwatch_log_group_retention_in_days = 30

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    disk_size                  = 128
    ami_type                   = "AL2023_ARM_64_STANDARD"
    instance_types             = ["t4g.large", "t4g.2xlarge"]
    iam_role_attach_cni_policy = true
    metadata_options = {
      "http_endpoint" : "enabled",
      "http_put_response_hop_limit" : 2,
      "http_tokens" : "required"
    }
    iam_role_additional_policies = {
      CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
    }
  }

  eks_managed_node_groups = {
    generic = {
      use_custom_launch_template = false

      min_size     = 3
      max_size     = 10
      desired_size = 5

      capacity_type = "ON_DEMAND"

      enable_monitoring = true
    }
  }
}

# NOTE: Use native AWS access controls instead for user permissions
# 
# module "eks-aws-auth" {
#   source  = "terraform-aws-modules/eks/aws//modules/aws-auth"
#   version = "~> 20.0"

#   manage_aws_auth_configmap = true

#   aws_auth_roles = [
#     {
#       rolearn  = aws_iam_role.github-actions-admin.arn
#       username = "gh_actions_admin_role"
#       groups   = ["system:masters"]
#     },
#   ]

#   aws_auth_users = [
#     {
#       userarn  = "arn:aws:iam::123456789123:user/mayowa"
#       username = "mayowa"
#       groups   = ["system:masters"]
#     },
#   ]
# }

resource "kubernetes_storage_class" "ebs-sc" {
  depends_on = [module.eks]
  metadata {
    name = "ebs-sc"
  }
  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"
}

output "oidc_provider" {
  value       = module.eks.oidc_provider
  description = "AWS EKS oidc_provider"
}

output "oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "AWS EKS oidc_provider_arn"
}

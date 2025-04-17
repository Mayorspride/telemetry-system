# Terraform 

## Prerequisites
Make sure you have run the `scripts/AWS_scripts/bootstrap-aws-subacct-terraform.sh` first.\
Also, make sure you have Terraform installed.

### Kubectl context
Note that sometimes, you may have to set the correct kubectl context as well
```
kubectl config set-context CLUSTER_NAME
```

## Configuration
Make sure to change this block appropriately.\
Open up `terraform/accounts/default/bootstrap.tf`
```
terraform {
  required_version = "1.9.8"
  backend "s3" {
    bucket         = "REPLACEME"
    key            = "infra/state"
    region         = "REPLACEME"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
      configuration_aliases = [
        aws.uswest1,
        aws.uswest2,
        aws.useast1,
        aws.useast2
      ]
    }
  }
}
```

### VPC configuration for EKS
Modify `terraform/accounts/default/mod_vpc.tf` and add the appropriate tags for the EKS cluster name into the subnets. 
```
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"            = "1"
    "kubernetes.io/cluster/sample-eks-cluster" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/role/elb"                     = "1"
    "kubernetes.io/cluster/sample-eks-cluster" = "shared"
  }
```

### Additional Helm chart configs
If you are using managed node groups for EKS, it can be helpful to install additional software such as ALB ingress controller.\
In this case, you should modify the cluster name as well in `terraform/accounts/default/helm.tf` 

For example:
```
data "template_file" "alb-ingress-values" {
  template = file("../../templates/helm/alb_ingress_values.yaml")
  vars = {
    image_tag    = "v2.10.1"
    repository   = "public.ecr.aws/eks/aws-load-balancer-controller"
    cluster_name = "REPLACEME"
    region       = data.aws_region.current.name
    vpc_id       = module.vpc.vpc_id
    role_arn     = aws_iam_role.aws-load-balancer-controller.arn
  }
}
```

## Running Terraform
Init
```
terraform init
```
Plan
```
terraform plan
```
Apply
```
terraform apply
```

### Sample output
Once finished, you should see the following 
```
Apply complete! Resources: 16 added, 0 changed, 0 destroyed.

Outputs:

oidc_provider = "oidc.eks.us-east-1.amazonaws.com/id/CA04377E1F2E0B78B47E4ED6CD05DC34"
oidc_provider_arn = "arn:aws:iam::088602178575:oidc-provider/oidc.eks.us-east-1.amazonaws.com/id/CA04377E1F2E0B78B47E4ED6CD05DC34"
private_subnet_arns = [
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-002b157f21858dbb9",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-0eb36a0fcbd61ca7e",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-014218abdcc191301",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-0628585a85b291b3f",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-0c9b85c3081972e42",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-009cd875c85092c19",
]
private_subnets = [
  "subnet-002b157f21858dbb9",
  "subnet-0eb36a0fcbd61ca7e",
  "subnet-014218abdcc191301",
  "subnet-0628585a85b291b3f",
  "subnet-0c9b85c3081972e42",
  "subnet-009cd875c85092c19",
]
private_subnets_cidr_blocks = tolist([
  "10.0.1.0/24",
  "10.0.2.0/24",
  "10.0.3.0/24",
  "10.0.4.0/24",
  "10.0.5.0/24",
  "10.0.6.0/24",
])
private_subnets_ipv6_cidr_blocks = tolist([])
public_subnet_arns = [
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-09310cfb3331da83e",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-03f05125c27d464c6",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-00751fa7ba416f371",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-0ab0ee2fbd102dc60",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-001c4a9bb0fae071c",
  "arn:aws:ec2:us-east-1:088602178575:subnet/subnet-0b6cf27b6317f8bf0",
]
public_subnets = [
  "subnet-09310cfb3331da83e",
  "subnet-03f05125c27d464c6",
  "subnet-00751fa7ba416f371",
  "subnet-0ab0ee2fbd102dc60",
  "subnet-001c4a9bb0fae071c",
  "subnet-0b6cf27b6317f8bf0",
]
public_subnets_cidr_blocks = tolist([
  "10.0.101.0/24",
  "10.0.102.0/24",
  "10.0.103.0/24",
  "10.0.104.0/24",
  "10.0.105.0/24",
  "10.0.106.0/24",
])
public_subnets_ipv6_cidr_blocks = tolist([])
vpc_id = "vpc-03999c89db0c547f8"
```
You can see the cluster for example by running:
```
aws --region=us-east-1 eks list-clusters
```
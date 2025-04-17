provider "aws" {
  region = "us-west-1"
  alias  = "uswest1"
}

provider "aws" {
  region = "us-west-2"
  alias  = "uswest2"
}

provider "aws" {
  region = "us-east-1"
  alias  = "useast1"
}

provider "aws" {
  region = "us-east-2"
  alias  = "useast2"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

terraform {
  required_version = "1.11.4"
  backend "s3" {
    bucket         = "tf-state-4be6684c-3d06-42fc-8e61-7606e5ab1f31"
    key            = "infra/state"
    region         = "us-east-1"
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

data "aws_region" "current" {}

data "aws_availability_zones" "available" {
  state = "available"

  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

data "aws_caller_identity" "current" {}

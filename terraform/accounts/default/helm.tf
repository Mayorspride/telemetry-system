// cert-manager
//
resource "helm_release" "cert-manager" {
  name       = "cert-manager"
  chart      = "cert-manager"
  repository = "https://charts.jetstack.io"
  namespace  = "kube-system"
  version    = "1.12.3"
  replace    = true
  set {
    name  = "installCRDs"
    value = true
  }
}

// ALB ingress controller
//
data "template_file" "alb-ingress-values" {
  template = file("../../templates/helm/alb_ingress_values.yaml")
  vars = {
    image_tag    = "v2.10.1"
    repository   = "public.ecr.aws/eks/aws-load-balancer-controller"
    cluster_name = "sample-eks-cluster"
    region       = data.aws_region.current.name
    vpc_id       = module.vpc.vpc_id
    role_arn     = aws_iam_role.aws-load-balancer-controller.arn
  }
}

resource "helm_release" "alb-ingress-controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.10.0"
  values = [
    data.template_file.alb-ingress-values.rendered
  ]
}

// Metrics server
//
resource "helm_release" "metrics-server" {
  name       = "metrics-server"
  chart      = "metrics-server"
  repository = "https://charts.bitnami.com/bitnami"
  namespace  = "kube-system"
  version    = "6.8.1"
  replace    = true
  values = [
    file("../../templates/helm/metric_server_values.yaml")
  ]
}

# // External DNS
# //
# data "template_file" "external-dns-values" {
#   template = file("../../templates/helm/external_dns_values.yaml")
#   vars = {
#     iam_role              = aws_iam_role.external-dns-k8s.arn
#     aws_access_key_id     = ""
#     aws_secret_access_key = ""
#     hosted_zone_id        = aws_route53_zone.sample-eks-cluster.zone_id
#     domain_filters        = "sample-eks-cluster.xyz"
#     prometheus_enabled    = "false"
#     sync_policy           = "upsert-only"
#   }
# }

# resource "helm_release" "external-dns" {
#   name       = "external-dns"
#   repository = "https://charts.bitnami.com/bitnami"
#   chart      = "external-dns"
#   namespace  = "kube-system"
#   replace    = true
#   version    = "6.35.0"
#   values = [
#     data.template_file.external-dns-values.rendered
#   ]
# }

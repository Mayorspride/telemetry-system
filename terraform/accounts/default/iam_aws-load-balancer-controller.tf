resource "aws_iam_policy" "aws-load-balancer-controller" {
  name_prefix = "ALBControllerIAMPolicy-"
  description = "Allow EKS pods to create ALB ingress"
  policy      = file("iam_json_files/iam_policy_aws-load-balancer-controller.json")
}

data "aws_iam_policy_document" "oidc-aws-load-balancer-controller" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${module.eks.oidc_provider}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }

    principals {
      identifiers = [module.eks.oidc_provider_arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "aws-load-balancer-controller" {
  name_prefix        = "iam-k8s-eks-alb-"
  description        = "Bind aws-load-balancer-controller to serviceaccount to OIDC"
  assume_role_policy = data.aws_iam_policy_document.oidc-aws-load-balancer-controller.json
}

resource "aws_iam_role_policy_attachment" "aws-load-balancer-controller" {
  role       = aws_iam_role.aws-load-balancer-controller.name
  policy_arn = aws_iam_policy.aws-load-balancer-controller.arn
}

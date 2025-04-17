resource "aws_kms_key" "eks" {
  description             = "Managed by Terraform. Used for encrypting EKS secrets."
  deletion_window_in_days = 7
}

resource "aws_kms_alias" "eks" {
  name_prefix   = "alias/eks-"
  target_key_id = aws_kms_key.eks.key_id
}

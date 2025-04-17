# AWS user management policies
#
# resource "aws_iam_account_password_policy" "strict" {
#   allow_users_to_change_password = true
#   password_reuse_prevention      = 24
#   hard_expiry                    = false
#   minimum_password_length        = 20 # > 256 bits of entropy
#   require_lowercase_characters   = true
#   require_uppercase_characters   = true
#   require_numbers                = true
#   require_symbols                = false
# }
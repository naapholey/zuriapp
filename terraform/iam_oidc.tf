# Fetch GitHub's OIDC OpenSSL Certificate Thumbprint
data "aws_iam_openid_connect_provider" "github" {
  url = "https://githubusercontent.com"
}

# OIDC Trust Policy Configuration
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    id_token_creators {
      provider_arn = data.aws_iam_openid_connect_provider.github.arn
      audience_ids = ["://amazonaws.com"]
    }

    # Strict scoping down to your specific GitHub workspace repository matching pattern
    condition {
      test     = "StringEquals"
      variable = "://githubusercontent.com:sub"
      values   = ["repo:naapholey/zuriapp:ref:refs/heads/main"]
    }
  }
}

# The IAM Automation deployment executor role
resource "aws_iam_role" "github_actions" {
  name               = "github-actions-zuri-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# Basic inline policy granting GitHub workflow capabilities (adjust specific perms as needed)
resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" # For demo day agility; scale down for real production
}

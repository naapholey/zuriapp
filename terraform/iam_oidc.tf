# Fetch GitHub's OIDC OpenSSL Certificate Thumbprint
data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# OIDC Trust Policy Configuration
data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    # FIX: Replaced invalid "id_token_creators" block with standard "principals"
    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    # FIX: Combined audience verification into standard IAM conditions 
    # and fixed the structural syntax for variable names
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"] # The official standard audience for AWS OIDC
    }

    # Strict scoping down to your specific GitHub workspace repository matching pattern
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:naapholey/zuriapp:ref:refs/heads/main"]
    }
  }
}

# The IAM Automation deployment executor role
resource "aws_iam_role" "github_actions" {
  name               = "github-actions-zuri-role"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

# Basic inline policy granting GitHub workflow capabilities
resource "aws_iam_role_policy_attachment" "admin_access" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess" 
}

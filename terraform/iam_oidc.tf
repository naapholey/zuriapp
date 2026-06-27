resource "aws_iam_openid_connect_provider" "github" {

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1"
  ]

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-github-oidc"
    }
  )
}

##############################################################
# GitHub OIDC Trust Policy
##############################################################

data "aws_iam_policy_document" "github_assume_role" {

  statement {

    sid = "GitHubOIDC"

    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {

      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    condition {

      test = "StringEquals"

      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {

      test = "StringLike"

      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
      ]
    }
  }
}

##############################################################
# GitHub Actions IAM Role
##############################################################

resource "aws_iam_role" "github_actions" {

  name = "${local.name_prefix}-github-actions"

  assume_role_policy = data.aws_iam_policy_document.github_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-github-actions"
    }
  )
}

##############################################################
# GitHub Deployment Policy
##############################################################

resource "aws_iam_policy" "github_deployment" {

  name = "${local.name_prefix}-github-deployment"

  description = "Permissions used by GitHub Actions"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      ########################################################
      # EC2
      ########################################################

      {
        Effect = "Allow"

        Action = [

          "ec2:*"

        ]

        Resource = "*"
      },

      ########################################################
      # VPC
      ########################################################

      {
        Effect = "Allow"

        Action = [

          "ec2:Describe*"

        ]

        Resource = "*"
      },

      ########################################################
      # IAM
      ########################################################

      {
        Effect = "Allow"

        Action = [

          "iam:GetRole",
          "iam:PassRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:CreateInstanceProfile",
          "iam:DeleteInstanceProfile",
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile"

        ]

        Resource = "*"
      },

      ########################################################
      # CloudWatch
      ########################################################

      {
        Effect = "Allow"

        Action = [

          "logs:*"

        ]

        Resource = "*"
      },

      ########################################################
      # KMS
      ########################################################

      {
        Effect = "Allow"

        Action = [

          "kms:DescribeKey"

        ]

        Resource = aws_kms_key.infrastructure.arn
      },

      ########################################################
      # Secrets Manager
      ########################################################

      {
        Effect = "Allow"

        Action = [

          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"

        ]

        Resource = aws_secretsmanager_secret.k3s_kubeconfig.arn
      }

    ]

  })
}

resource "aws_iam_role_policy_attachment" "github_deployment" {

  role = aws_iam_role.github_actions.name

  policy_arn = aws_iam_policy.github_deployment.arn

}

# K3s Kubeconfig Secret

import {
  to = aws_secretsmanager_secret.k3s_kubeconfig
  id = "arn:aws:secretsmanager:us-east-1:870737143368:secret:zuri-k3s-kubeconfig-gP9xpo"
}
resource "aws_secretsmanager_secret" "k3s_kubeconfig" {

  name = var.kubeconfig_secret_name

  description = "K3s kubeconfig used by GitHub Actions"

  kms_key_id = aws_kms_key.infrastructure.arn

  recovery_window_in_days = 7

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-kubeconfig"
    }
  )
}


# Placeholder Secret Version
#
# The actual kubeconfig is uploaded by the EC2 bootstrap
# after K3s has been installed.


resource "aws_secretsmanager_secret_version" "placeholder" {

  secret_id = aws_secretsmanager_secret.k3s_kubeconfig.id

  secret_string = jsonencode({
    status = "Waiting for K3s bootstrap"
  })

  lifecycle {
    ignore_changes = [
      secret_string
    ]
  }
}

import {
  to = aws_iam_policy.k3s_secret_write
  id = "arn:aws:iam::870737143368:policy/zuriapp-dev-k3s-secret-write"
}
resource "aws_iam_policy" "k3s_secret_write" {

  name = "${local.name_prefix}-k3s-secret-write"

  description = "Allow EC2 to manage kubeconfig secret"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret"

        ]

        Resource = aws_secretsmanager_secret.k3s_kubeconfig.arn

      }

    ]

  })
}

resource "aws_iam_role_policy_attachment" "ec2_secret_policy" {

  role = aws_iam_role.ec2_k3s_role.name

  policy_arn = aws_iam_policy.k3s_secret_write.arn

}

import {
  to = aws_iam_policy.github_secret_read
  id = "arn:aws:iam::870737143368:policy/zuriapp-dev-github-secret-read"
}
resource "aws_iam_policy" "github_secret_read" {

  name = "${local.name_prefix}-github-secret-read"

  description = "Allow GitHub Actions to retrieve kubeconfig"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

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

resource "aws_iam_role_policy_attachment" "github_secret_policy" {

  role = aws_iam_role.github_actions.name

  policy_arn = aws_iam_policy.github_secret_read.arn

}
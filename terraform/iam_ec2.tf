##############################################################
# EC2 Trust Policy
##############################################################

data "aws_iam_policy_document" "ec2_assume_role" {

  statement {

    sid = "EC2AssumeRole"

    effect = "Allow"

    actions = [
      "sts:AssumeRole"
    ]

    principals {

      type = "Service"

      identifiers = [
        "ec2.amazonaws.com"
      ]
    }
  }
}

##############################################################
# EC2 IAM Role
##############################################################

resource "aws_iam_role" "ec2_k3s_role" {

  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(
    local.common_tags,
    {
      Name = "${local.name_prefix}-ec2-role"
    }
  )
}

##############################################################
# Instance Profile
##############################################################

resource "aws_iam_instance_profile" "k3s" {

  name = "${local.name_prefix}-instance-profile"

  role = aws_iam_role.ec2_k3s_role.name

}

resource "aws_iam_role_policy_attachment" "ssm" {

  role = aws_iam_role.ec2_k3s_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"

}

resource "aws_iam_role_policy_attachment" "cloudwatch" {

  role = aws_iam_role.ec2_k3s_role.name

  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"

}

resource "aws_iam_policy" "ec2_secrets_manager" {

  name = "${local.name_prefix}-secretsmanager"

  description = "Allow EC2 to manage K3s kubeconfig"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Sid = "SecretsManager"

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

resource "aws_iam_role_policy_attachment" "secrets_manager" {

  role = aws_iam_role.ec2_k3s_role.name

  policy_arn = aws_iam_policy.ec2_secrets_manager.arn

}

resource "aws_iam_policy" "kms" {

  name = "${local.name_prefix}-kms"

  description = "Allow EC2 to use customer managed KMS key"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Sid = "KMS"

        Effect = "Allow"

        Action = [

          "kms:Encrypt",

          "kms:Decrypt",

          "kms:GenerateDataKey",

          "kms:DescribeKey"

        ]

        Resource = aws_kms_key.infrastructure.arn

      }

    ]

  })
}

resource "aws_iam_role_policy_attachment" "kms" {

  role = aws_iam_role.ec2_k3s_role.name

  policy_arn = aws_iam_policy.kms.arn

}

resource "aws_iam_policy" "cloudwatch_logs" {

  name = "${local.name_prefix}-logs"

  description = "Allow EC2 to publish logs"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "logs:CreateLogGroup",

          "logs:CreateLogStream",

          "logs:DescribeLogStreams",

          "logs:PutLogEvents"

        ]

        Resource = "*"

      }

    ]

  })
}

resource "aws_iam_role_policy_attachment" "logs" {

  role       = aws_iam_role.ec2_k3s_role.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn

}

resource "aws_iam_policy" "ec2_read" {

  name = "${local.name_prefix}-ec2-read"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Action = [

          "ec2:DescribeInstances",

          "ec2:DescribeVolumes",

          "ec2:DescribeTags",

          "ec2:DescribeSubnets",

          "ec2:DescribeVpcs"

        ]

        Resource = "*"

      }

    ]

  })
}

resource "aws_iam_role_policy_attachment" "ec2_read" {

  role = aws_iam_role.ec2_k3s_role.name

  policy_arn = aws_iam_policy.ec2_read.arn

}
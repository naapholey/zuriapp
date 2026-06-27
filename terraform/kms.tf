
# Current AWS Account
data "aws_caller_identity" "current" {}


# KMS Key Policy
data "aws_iam_policy_document" "kms" {
  # Root account full access
  statement {

    sid    = "EnableRootPermissions"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }

    actions = [
      "kms:*"
    ]

    resources = [
      "*"
    ]
  }


  # CloudWatch Logs
  statement {

    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "logs.${var.aws_region}.amazonaws.com"
      ]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]

    resources = [
      "*"
    ]
  }


  # Secrets Manager

  statement {
    sid    = "AllowSecretsManager"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "secretsmanager.amazonaws.com"
      ]
    }

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]

    resources = [
      "*"
    ]
  }

}


# Customer Managed KMS Key
resource "aws_kms_key" "infrastructure" {

  description             = "KMS key for ${local.name_prefix}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms.json

  tags = merge(
    local.common_tags,

    {
      Name = "${local.name_prefix}-kms"
    }
  )
}

##############################################################
# Alias
##############################################################
import {
  to = aws_kms_alias.infrastructure
  id = "alias/${local.name_prefix}"
}
resource "aws_kms_alias" "infrastructure" {

  name = "alias/${local.name_prefix}"

  target_key_id = aws_kms_key.infrastructure.key_id
}
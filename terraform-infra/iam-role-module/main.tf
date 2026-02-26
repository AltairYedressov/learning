data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = var.principal_type
      identifiers = var.principal_identifiers
    }

    dynamic "condition" {
      for_each = var.assume_role_conditions
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  assume_role_policy   = data.aws_iam_policy_document.assume_role.json
  permissions_boundary = var.permissions_boundary_arn

  tags = {
    Name        = var.role_name
    environment = var.environment
  }
}

resource "aws_iam_policy" "custom" {
  for_each = var.custom_policy_json_path != null ? { custom = var.custom_policy_json_path } : {}

  name   = "${var.role_name}-custom-policy"
  policy = file(each.value)

  tags = {
    Name        = "${var.role_name}-custom-policy"
    environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "custom" {
  for_each = aws_iam_policy.custom

  role       = aws_iam_role.this.name
  policy_arn = each.value.arn
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.aws_managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}
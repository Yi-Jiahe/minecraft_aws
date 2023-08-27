data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda.py"
  output_path = "${path.module}/lambda_function_payload.zip"
}

resource "aws_lambda_function" "launcher_lambda" {
  filename      = "lambda_function_payload.zip"
  function_name = "launcher_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
      REGION  = var.region
      CLUSTER = var.cluster.name
      SERVICE = aws_ecs_service.minecraft.name
    }
  }
}

resource "aws_cloudwatch_log_subscription_filter" "dns_trigger_lambda_filter" {
  name            = "dns_trigger_lambda_filter"
  role_arn        = aws_iam_role.iam_for_lambda.arn
  log_group_name  = "/aws/route53/${var.domain}"
  filter_pattern  = var.subdomain
  destination_arn = aws_lambda_function.launcher_lambda.arn 
}
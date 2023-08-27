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
  provider = aws.us-east-1

  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "terraform_lambda_policy" {
  role       = "${aws_iam_role.iam_for_lambda.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "launcher_lambda" {
  provider = aws.us-east-1

  filename      = "lambda_function_payload.zip"
  function_name = "launcher_lambda"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda_function.lambda_handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "python3.8"

  environment {
    variables = {
      REGION  = var.region
      CLUSTER = aws_ecs_cluster.minecraft_cluster.name
      DOMAIN = var.domain
    }
  }
}

resource "aws_cloudwatch_log_subscription_filter" "dns_trigger_lambda_filter" {
  provider = aws.us-east-1

  depends_on = [aws_lambda_permission.allow_cloudwatch]
  name            = "dns_trigger_lambda_filter"
  log_group_name  = "/aws/route53/${var.domain}"
  filter_pattern  = "\".${var.domain}\""
  destination_arn = aws_lambda_function.launcher_lambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  provider = aws.us-east-1

  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.launcher_lambda.function_name
  principal     = "logs.us-east-1.amazonaws.com"
  source_arn = "${aws_cloudwatch_log_group.aws_route53_minecraft_zone.arn}:*"
}

data "aws_iam_policy_document" "describe_services_policy" {
  statement {
    actions = ["ecs:DescribeServices"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "describe_services_policy" {
  name   = "describe_services_policy"
  policy = data.aws_iam_policy_document.describe_services_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_describe_service_policy_to_lambda_role" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.describe_services_policy.arn
}
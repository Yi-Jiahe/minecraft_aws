data "aws_route53_zone" "minecraft_zone" {
  name = var.domain
}

/*
https://registry.terraform.io/providers/hashicorp/aws/5.12.0/docs/resources/route53_query_log
There are restrictions on the configuration of query logging. 
Notably, the CloudWatch log group must be in the us-east-1 region, a permissive CloudWatch log resource policy must be in place, and the Route53 hosted zone must be public. 
*/

resource "aws_cloudwatch_log_group" "aws_route53_minecraft_zone" {
  provider = aws.us-east-1

  name              = "/aws/route53/${var.domain}"
  retention_in_days = 3
}

data "aws_iam_policy_document" "route53-query-logging-policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:log-group:/aws/route53/*"]

    principals {
      identifiers = ["route53.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_cloudwatch_log_resource_policy" "route53-query-logging-policy" {
  provider = aws.us-east-1

  policy_document = data.aws_iam_policy_document.route53-query-logging-policy.json
  policy_name     = "route53-query-logging-policy"
}

resource "aws_route53_query_log" "minecraft_zone" {
  depends_on = [aws_cloudwatch_log_resource_policy.route53-query-logging-policy]

  cloudwatch_log_group_arn = aws_cloudwatch_log_group.aws_route53_minecraft_zone.arn
  zone_id                  = data.aws_route53_zone.minecraft_zone.zone_id
}

resource "aws_ecs_cluster" "minecraft_cluster" {
  name = "minecraft"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

module "vanilla_server" {
  source = "./modules/server"
  
  region = var.region

  domain = var.domain
  subdomain = var.servers[0]["subdomain"]

  zone_id = data.aws_route53_zone.minecraft_zone.id

  cluster = {
    id   = aws_ecs_cluster.minecraft_cluster.id,
    name = aws_ecs_cluster.minecraft_cluster.name
  }

  public_subnet_id = aws_subnet.public.id
  private_subnet_id = aws_subnet.private.id
  security_group_id = aws_security_group.minecraft_sg.id

  launcher_lambda_role_name = aws_iam_role.iam_for_lambda.name

  cpu = var.servers[0]["cpu"]
  memory = var.servers[0]["memory"]
}
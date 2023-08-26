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

  name              = "/aws/route53/${data.aws_route53_zone.minecraft_zone.name}"
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

resource "aws_security_group" "minecraft-sg" {
  description = "Allows inbound Minecraft traffic (TCP on port 25565) for all IPs"

  ingress {
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_ecs_cluster" "minecraft_cluster" {
  name = "minecraft"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

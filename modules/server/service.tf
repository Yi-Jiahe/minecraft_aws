locals {
  task_volume_name = "minecraft_storage"
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_role" {
  name = "ecs_minecraft_task_role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_efs_read_write_data_policy_to_task_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.efs_read_write_data_policy.arn
}

resource "aws_ecs_service" "minecraft" {
  name          = "minecraft"
  cluster       = var.cluster.id
  desired_count = 0
  network_configuration {
    subnets = [var.subnet_id]
    security_groups = [var.security_group_id]
    assign_public_ip = true
  }

  launch_type = "FARGATE"
}

resource "aws_ecs_task_definition" "service" {
  family                  = "service"
  requires_compatibilities = ["FARGATE"]
  cpu                     = var.cpu
  memory                  = var.memory

  container_definitions = jsonencode([
    {
      name      = "minecraft"
      image     = "itzg/minecraft-server"
      essential = false
      portMappings = [
        {
          containerPort = 25565
          hostPort      = 25565
          protocol      = "tcp"
        }

      ]
      environment = [
        { EULA : "TRUE" }
      ]
      mountPoints = [
        {
          sourceVolume  = local.task_volume_name
          containerPath = "/data"
          readOnly      = "false"
        }
      ]
    },
    {
      name      = "watchdog"
      image     = "doctorray/minecraft-ecsfargate-watchdog"
      essential = true
      environment = [
        { CLUSTER = var.cluster.name },
        { SERVICE = aws_ecs_service.minecraft },
        { DNSZONE = var.zone_id },
        { SERVERNAME = "${var.subdomain}.${var.domain}" }
      ]
    }
  ])

  volume {
    name = local.task_volume_name

    efs_volume_configuration {
      file_system_id     = aws_efs_file_system.server_file_system.id
      transit_encryption = "ENABLED"
      authorization_config {
        access_point_id = aws_efs_access_point.server_access_point.id
        iam             = "ENABLED"
      }
    }
  }
}

resource "aws_ecs_task_set" "minecraft_service_set" {
  service         = aws_ecs_service.minecraft.id
  cluster         = var.cluster.id
  task_definition = aws_ecs_task_definition.service.id
}

data "aws_iam_policy_document" "service_control_policy" {
  statement {
    actions = ["ecs:*"]
    resources = [
      aws_ecs_service.minecraft.id,
      "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.id}:task/${var.cluster.name}/*"
    ]
  }

  statement {
    actions   = ["ec2:DescribeNetworkInterfaces"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "service_control_policy" {
  name = "service_control_policy"
  policy = data.aws_iam_policy_document.service_control_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_service_control_policy_to_task_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.service_control_policy.arn
}

data "aws_iam_policy_document" "route53_policy" {
  statement {
    actions = [
      "route53:GetHostedZone",
      "route53:ChangeResourceRecordSets",
      "route53:ListResourceRecordSets"
    ]
    resources = [
      "arn:aws:route53:::hostedzone/${var.zone_id}"
    ]
  }
}

resource "aws_iam_policy" "route53_policy" {
  name = "route53_policy"
  policy = data.aws_iam_policy_document.route53_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_route53_policy_to_task_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.route53_policy.arn
}


locals {
  service_name     = var.subdomain 
  task_volume_name = "minecraft_storage"
}

data "aws_caller_identity" "current" {}

resource "aws_route53_record" "subdomain" {
  zone_id = var.zone_id
  name    = "${var.subdomain}.${var.domain}"
  type    = "A"
  ttl     = 30
  # Temporary value which will change when the container launches.
  records = ["192.168.1.1"]
}

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
  name = "ecs_minecraft_task_role_${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs_minecraft_task_execution_role_${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
}


resource "aws_iam_role_policy_attachment" "attach_efs_read_write_data_policy_to_task_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.efs_read_write_data_policy.arn
}

resource "aws_ecs_service" "minecraft" {
  name            = local.service_name
  cluster         = var.cluster.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 0
  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.minecraft_security_group_id]
    assign_public_ip = true
  }
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight = 1
  }
}

resource "aws_ecs_task_definition" "service" {
  family                   = var.subdomain
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory
  task_role_arn       = aws_iam_role.ecs_task_role.arn
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  network_mode = "awsvpc"

  container_definitions = jsonencode([
    {
      name      = "minecraft"
      image     = "itzg/minecraft-server"
      cpu = var.cpu
      memory = var.memory
      essential = false
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = aws_cloudwatch_log_group.minecraft_log_group.name
          awslogs-region = var.region
          awslogs-stream-prefix = "minecraft"
        }
      }
      portMappings = [
        {
          containerPort = 25565
          hostPort      = 25565
          protocol      = "tcp"
        }
      ]
      environment = concat(
        [ for name, value in var.env_vars: { name: name, value: value } ], 
        [
          { name: "MEMORY", value: "" }, 
          { name: "JVM_XX_OPTS", value: "-XX:MaxRAMPercentage=75" }
        ]
      )
      
      mountPoints = [
        {
          sourceVolume  = local.task_volume_name
          containerPath = "/data"
          readOnly      = false
        }
      ]
    },
    {
      name      = "watchdog"
      image     = "doctorray/minecraft-ecsfargate-watchdog"
      essential = true
      environment = [
        {
          name  = "CLUSTER"
          value = var.cluster.name
        },
        {
          name  = "SERVICE"
          value = local.service_name
        },
        {
          name  = "DNSZONE"
          value = var.zone_id
        },
        {
          name  = "SERVERNAME"
          value = "${var.subdomain}.${var.domain}"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group = aws_cloudwatch_log_group.minecraft_log_group.name
          awslogs-region = var.region
          awslogs-stream-prefix = "watchdog"
        }
      }
    }
  ])
  volume {
    name = local.task_volume_name

    efs_volume_configuration {
      file_system_id = aws_efs_file_system.server_file_system.id
    }
  }

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }
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
  name   = "service_control_policy"
  policy = data.aws_iam_policy_document.service_control_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_service_control_policy_to_task_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.service_control_policy.arn
}

resource "aws_iam_role_policy_attachment" "attach_service_control_policy_to_lambda_role" {
  role       = var.launcher_lambda_role_name
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
  name   = "${var.subdomain}_route53_policy"
  policy = data.aws_iam_policy_document.route53_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_route53_policy_to_task_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.route53_policy.arn
}

resource "aws_cloudwatch_log_group" "minecraft_log_group" {
  name = "/ecs/${var.subdomain}"
}

data "aws_iam_policy_document" "minecraft_logging_policy" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]

    resources = ["arn:aws:logs:*:*:log-group:/ecs/${var.subdomain}:*"]
  }
}

resource "aws_iam_policy" "minecraft_log_group_policy" {
  name   = "minecraft_logging_policy"
  policy = data.aws_iam_policy_document.minecraft_logging_policy.json
}

resource "aws_iam_role_policy_attachment" "attach_minecraft_log_group_policy_to_task_role" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.minecraft_log_group_policy.arn
}

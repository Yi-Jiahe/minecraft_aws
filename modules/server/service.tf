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

  launch_type = "FARGATE"
}

resource "aws_ecs_task_definition" "service" {
  family = "service"
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

    },
    {
      name      = "watchdog"
      image     = "doctorray/minecraft-ecsfargate-watchdog"
      essential = true
      environment = [
        { CLUSTER = var.cluster.name },
        { SERVICE = aws_ecs_service.minecraft }
      ]
    }
  ])

  volume {
    name = "minecraft_storage"

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
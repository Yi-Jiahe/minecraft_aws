resource "aws_efs_file_system" "server_file_system" {
}

resource "aws_efs_access_point" "server_access_point" {
  file_system_id = aws_efs_file_system.server_file_system.id
  root_directory {
    path = "/minecraft"
    creation_info {
    owner_gid   = "1000"
    owner_uid   = "1000"
    permissions = "0755"
    }
  }
  posix_user {
    gid = "1000"
    uid = "1000"
  }
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
  name = "test_role"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
}

data "aws_iam_policy_document" "efs_read_write_data_policy" {
  statement {
    actions = [
      "elasticfilesystem:ClientMount",
      "elasticfilesystem:ClientWrite",
      "elasticfilesystem:DescribeFileSystems",
    ]

    resources = [aws_efs_file_system.server_file_system.arn]

    condition {
      test     = "ForAnyValue:StringEquals"
      variable = "elasticfilesystem:AccessPointArn"
      values   = [aws_efs_access_point.server_access_point.arn]
    }
  }
}

resource "aws_iam_policy" "efs_read_write_data_policy" {
  policy = data.aws_iam_policy_document.efs_read_write_data_policy.json
  name     = "efs_read_write_data_policy"
}

resource "aws_iam_role_policy_attachment" "attach_efs_read_write_data_policy_to_task_role" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.efs_read_write_data_policy.arn
}
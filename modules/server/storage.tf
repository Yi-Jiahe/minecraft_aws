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

resource "aws_efs_mount_target" "private" {
  count = length(var.private_subnet_ids)
  file_system_id = aws_efs_file_system.server_file_system.id
  subnet_id      = var.private_subnet_ids[count.index]
  security_groups = [var.efs_security_group_id]
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
  name   = "efs_read_write_data_policy"
}

data "aws_iam_policy_document" "datasync_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["datasync.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "datasync_role" {
  name = "datasync_role_${var.subdomain}"

  assume_role_policy = data.aws_iam_policy_document.datasync_assume_role_policy.json
}
/*
resource "aws_iam_role_policy_attachment" "attach_datasync_full_access_policy_to_datasync_role" {
  role       = aws_iam_role.datasync_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSDataSyncFullAccess"
}
*/
resource "aws_iam_role_policy_attachment" "attach_s3_full_access_policy_to_datasync_role" {
  role       = aws_iam_role.datasync_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_datasync_location_efs" "datasync" {
  efs_file_system_arn = aws_efs_file_system.server_file_system.arn

  ec2_config {
    security_group_arns = [data.aws_security_group.minecraft_sg.arn]
    subnet_arn          = data.aws_subnet.private_subnet_1.arn 
  }

  in_transit_encryption = "NONE"

  subdirectory = "/"
}

resource "aws_datasync_location_s3" "datasync" {
  s3_bucket_arn = var.bucket_arn
   subdirectory  = "${var.subdomain}"
  s3_config {
    bucket_access_role_arn = aws_iam_role.datasync_role.arn
  }
  s3_storage_class =  "STANDARD"
}

resource "aws_datasync_task" "download_efs_contents" {
  name                     = "${var.subdomain}_datasync"
  source_location_arn      = aws_datasync_location_efs.datasync.arn
  destination_location_arn = aws_datasync_location_s3.datasync.arn

  options {
    overwrite_mode= "ALWAYS"
    preserve_deleted_files = "REMOVE"
  }
}

resource "aws_datasync_task" "upload_s3_contents" {
  name                     = "${var.subdomain}_datasync"
  source_location_arn      = aws_datasync_location_s3.datasync.arn
  destination_location_arn = aws_datasync_location_efs.datasync.arn

  options {
    overwrite_mode= "ALWAYS"
    preserve_deleted_files = "REMOVE"
  }
}


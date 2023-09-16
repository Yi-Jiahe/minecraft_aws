data "aws_security_group" "minecraft_sg" {
  id = var.minecraft_security_group_id
}

data "aws_subnet" "private_subnet_1" {
  id = var.private_subnet_ids[0]
}
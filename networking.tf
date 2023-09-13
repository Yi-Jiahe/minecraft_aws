resource "aws_vpc" "minecraft" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
}

data "aws_availability_zones" "available" {}

resource "aws_subnet" "public" {
  count = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = aws_vpc.minecraft.id
  cidr_block = "10.0.${10+count.index}.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
}

resource "aws_subnet" "private" {
  count = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = aws_vpc.minecraft.id
  cidr_block = "10.0.${20+count.index}.0/24"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
}

resource "aws_security_group" "minecraft_sg" {
  description = "Allows inbound Minecraft traffic (TCP on port 25565) for all IPs"
  vpc_id = aws_vpc.minecraft.id

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

resource "aws_security_group" "efs_sg" {
  vpc_id = aws_vpc.minecraft.id

  ingress {
    security_groups = [aws_security_group.minecraft_sg.id]
    from_port = 2049
    to_port = 2049
    protocol = "tcp"
  }

  egress {
    security_groups = [aws_security_group.minecraft_sg.id]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.minecraft.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.minecraft.id
}

resource "aws_route_table_association" "public_subnet" {
  count = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
terraform {
	  cloud {
    organization = "yi-jiahe"
    workspaces {
      name = "aws_minecraft_server"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.12.0"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "ap-southeast-1"
}

resource "aws_instance" "minecraft_server" {
  ami           = "ami-091a58610910a87a9"
  instance_type = "t3.small"
  vpc_security_group_ids = [aws_security_group.minecraft-sg.id]

  user_data = "${file("init.sh")}"
}

resource "aws_security_group" "minecraft-sg" {
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
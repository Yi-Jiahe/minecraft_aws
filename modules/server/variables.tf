variable "region" {
  type = string
}

variable "zone_id" {
  type = string
}

variable "domain" {
  type = string
}

variable "subdomain" {
  type = string
}

variable "cluster" {
  type = object({
    id   = string
    name = string
  })
}

variable "cpu" {
  type = number
}

variable "memory" {
  type = number
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "minecraft_security_group_id" {
  type = string
}

variable "efs_security_group_id" {
  type = string
}

variable "launcher_lambda_role_name" {
  type = string
}

variable "bucket_arn" {
  type = string
}
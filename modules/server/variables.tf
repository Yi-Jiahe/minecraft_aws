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

variable "public_subnet_id" {
  type = string
}

variable "private_subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "launcher_lambda_role_name" {
  type = string
}


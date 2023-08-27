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

variable "query_log_group_arn" {
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

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}
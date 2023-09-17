variable "region" {
  type = string
}

variable "domain" {
  type = string
}

variable "bucket_name" {
  type = string
}

variable "servers" {
  type = list(object({
    subdomain = string
    cpu = number
    memory = number
    env_vars = map(string)
  }))
}
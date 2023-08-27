variable "region" {
  type = string
}

variable "domain" {
  type = string
}

variable "servers" {
  type = list(object({
    subdomain = string
    cpu = number
    memory = number
  }))
}
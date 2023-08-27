variable "region" {
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
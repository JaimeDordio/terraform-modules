variable "title" {
  description = "Title of the service."
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "vpc" {
  description = "VPC"
  type = object({
    vpc_id  = string
    subnets = list(string)
  })
}

variable "cluster_name" {
  description = "Name of the cluster."
  type        = string
}

variable "container_port" {
  description = "The port number on the container."
  type        = number
  default     = 4242
}

variable "host_port" {
  description = "The port number on the host."
  type        = number
  default     = 4242
}

variable "environment_variables" {
  description = "Environment variables to pass to the container."
  type = list(object({
    name  = string
    value = string
  }))
}

variable "certificate_arn" {
  description = "ARN of the certificate to use for HTTPS."
  type        = string
}

variable "desired_count" {
  description = "The number of instances of the task to place and keep running."
  type        = number
  default     = 1
}

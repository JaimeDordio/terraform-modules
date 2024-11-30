variable "title" {
  description = "The title of the database"
  type        = string
}

variable "name" {
  description = "The name of the database"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "The IDs of the subnets"
  type        = list(string)
}

variable "password" {
  description = "The password for the database"
  type        = string
}

variable "region" {
  description = "The region of the database"
  type        = string
  default     = "eu-west-1"
}

variable "allocated_storage" {
  description = "The amount of allocated storage for the database"
  type        = number
  default     = 20
}

variable "engine_version" {
  description = "The engine version of the database"
  type        = string
  default     = "14.10"
}

variable "instance_class" {
  description = "The instance class of the database (default: db.t4g.micro [Free Tier Eligible])"
  type        = string
  default     = "db.t4g.micro"
}

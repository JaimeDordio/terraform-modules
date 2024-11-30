terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "5.22.0"
      configuration_aliases = [aws.primary_region]
    }
  }
}

resource "aws_db_subnet_group" "alonear_db_subnets" {
  name       = "${var.name}-subnet-group"
  subnet_ids = var.subnet_ids

  tags = {
    Name = "${var.title} DB Subnet Group"
  }
}

resource "aws_security_group" "alonear_db_sg" {
  vpc_id      = var.vpc_id
  name        = "${var.name}-sg"
  description = "${var.title} DB Security Group"

  tags = {
    Name = "${var.title} DB Security Group"
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "alonear_db" {
  identifier = var.name

  instance_class    = "db.t4g.micro"
  allocated_storage = 20
  engine            = "postgres"
  engine_version    = "14.12"

  skip_final_snapshot    = true
  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.alonear_db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.alonear_db_subnets.name

  username = "postgres"
  password = var.password
}

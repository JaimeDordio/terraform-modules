terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "5.22.0"
      configuration_aliases = [aws.primary_region]
    }
  }
}

# ###################################
# ECS TASK EXECUTION ROLE
# ###################################

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.cluster_name}-ecs-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_execution_role.name
}

# ###################################
# ECR REPO
# ###################################
resource "aws_ecr_repository" "api_ecr_repo" {
  name = var.cluster_name

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_iam_policy" "ecr_access_policy" {
  name        = "${var.cluster_name}-ecr-access-policy"
  description = "Policy to allow ECS tasks to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach the ECR access policy to the ECS task execution role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_ecr_policy" {
  policy_arn = aws_iam_policy.ecr_access_policy.arn
  role       = aws_iam_role.ecs_task_execution_role.name
}

# ###################################
# ECS CLUSTER
# ###################################
resource "aws_ecs_cluster" "api_ecs_cluster" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

}

# ###################################
# ECS TASK DEFINITION
# ###################################
resource "aws_ecs_task_definition" "api_ecs_task" {
  family = "${var.cluster_name}-task"
  container_definitions = jsonencode(
    [
      {
        "name" : "${var.cluster_name}-task",
        "image" : "${aws_ecr_repository.api_ecr_repo.repository_url}",
        "essential" : true,
        "portMappings" : [
          {
            "containerPort" : "${var.container_port}",
            "hostPort" : "${var.host_port}"
          }
        ],
        "environment" : [
          for env_var in var.environment_variables : {
            name  = env_var.name
            value = env_var.value
          }
        ],
        "logConfiguration" : {
          "logDriver" : "awslogs",
          "options" : {
            "awslogs-group" : "${aws_cloudwatch_log_group.api_task_log_group.name}",
            "awslogs-region" : "${var.region}",
            "awslogs-stream-prefix" : "ecs"
          }
        },
        "memory" : 512,
        "cpu" : 256
      }
  ])

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
}

# ###################################
# ECS SERVICE
# ###################################
resource "aws_ecs_service" "api_ecs_service" {
  name            = "${var.cluster_name}-service"
  cluster         = aws_ecs_cluster.api_ecs_cluster.id
  task_definition = aws_ecs_task_definition.api_ecs_task.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  load_balancer {
    target_group_arn = aws_lb_target_group.api_lb_target_group.arn
    container_name   = aws_ecs_task_definition.api_ecs_task.family
    container_port   = var.container_port
  }

  network_configuration {
    subnets = [
      "${var.vpc.subnets[0]}",
      "${var.vpc.subnets[1]}",
      "${var.vpc.subnets[2]}"
    ]
    assign_public_ip = true
    security_groups  = ["${aws_security_group.api_ecs_service_sg.id}"]
  }
}

# ###################################
# ECS SERVICE SECURITY CONFIGURATION
# ###################################
resource "aws_security_group" "api_ecs_service_sg" {
  name        = "${var.cluster_name}-service-sg"
  vpc_id      = var.vpc.vpc_id
  description = "${var.title} Service Security Group"

  tags = {
    Name = "${var.title} Service Security Group"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.api_lb_sg.id}"]
  }
}

# ###################################
# ECS SERVICE LOGGING CONFIGURATION
# ###################################
resource "aws_cloudwatch_log_group" "api_task_log_group" {
  name = "ecs/${var.cluster_name}-task"
}


# ###################################
# LOAD BALANCER CONFIGURATION
# ###################################
resource "aws_alb" "api_lb" {
  name               = "${var.cluster_name}-lb"
  load_balancer_type = "application"
  subnets            = var.vpc.subnets

  security_groups = ["${aws_security_group.api_lb_sg.id}"]
}

resource "aws_security_group" "api_lb_sg" {
  name        = "${var.cluster_name}-lb-sg"
  vpc_id      = var.vpc.vpc_id
  description = "${var.title} LB Security Group"

  tags = {
    Name = "${var.title} LB Security Group"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lb_target_group" "api_lb_target_group" {
  name        = "${var.cluster_name}-lb-target-group"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc.vpc_id

  health_check {
    matcher = "200,301,302,304,404"
    path    = "/"
  }
}

resource "aws_lb_listener" "api_lb_listener" {
  load_balancer_arn = aws_alb.api_lb.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api_lb_target_group.arn
  }
}

resource "aws_lb_listener_certificate" "api_lb_listener_cert" {
  listener_arn    = aws_lb_listener.api_lb_listener.arn
  certificate_arn = var.certificate_arn
}

provider "aws" {
  region     = "us-west-2"
  access_key = "AWS_ACCESS_KEY_ID"
  secret_key = "AWS_SECRET_ACCESS_KEY"
}

resource "aws_ecs_cluster" "hello_world_cluster" {
  name = "hello-world-cluster"
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "hello-world-ecs-task-execution-role"
  assume_role_policy = <<POLICY
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  }
  POLICY
}

resource "aws_lb" "example" {
  name               = "example-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["sg-0bae9cee9f52b5899"] # Use your security group ID
  subnets            = ["subnet-0af857850cc317c68"] # Use your subnet IDs
}

resource "aws_lb_target_group" "example" {
  name     = "example-tg"
  port     = 3000
  protocol = "HTTP"
  vpc_id   = "vpc-0adb17aaa75461b6a" # Replace with your VPC ID

  health_check {
    interval            = 30
    path                = "/"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

resource "aws_lb_listener" "example" {
  load_balancer_arn = aws_lb.example.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.example.arn
  }
}

resource "aws_ecs_task_definition" "hello_world_task" {
  family                   = "hello-world-task"
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = <<DEFINITION
  [
    {
      "name": "hello-world-container",
      "image": "node:14",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ]
    }
  ]
  DEFINITION
}

resource "aws_ecs_service" "hello_world_service" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.hello_world_cluster.id
  task_definition = aws_ecs_task_definition.hello_world_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = ["subnet-0af857850cc317c68"] # Use your subnet IDs
    security_groups = ["sg-0bae9cee9f52b5899"]     # Use your security group ID
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.example.arn
    container_name   = "hello-world-container"
    container_port   = 3000
  }

  depends_on = [aws_lb_listener.example]
}

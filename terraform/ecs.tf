# ECS Deployment Configuration

# ECR Repository for Docker Images
resource "aws_ecr_repository" "automation_ui" {
  name                 = "${var.project_name}-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${var.project_name}-ecr"
  }
}

# ECR Lifecycle Policy - Keep last 10 images
resource "aws_ecr_lifecycle_policy" "automation_ui" {
  repository = aws_ecr_repository.automation_ui.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus     = "any"
        countType     = "imageCountMoreThan"
        countNumber   = 10
      }
      action = {
        type = "expire"
      }
    }]
  })
}

# CloudWatch Log Groups removed due to IAM permission restrictions
# Logs can be viewed in ECS console under task details

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.project_name}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager access
resource "aws_iam_role_policy" "ecs_secrets_policy" {
  name = "${var.project_name}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ]
      Effect   = "Allow"
      Resource = aws_secretsmanager_secret.app_secrets.arn
    }]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "ecs_logs_policy" {
  name = "${var.project_name}-ecs-logs-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = ["logs:CreateLogGroup"]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}"
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${var.project_name}:*"
      }
    ]
  })
}

# ECS Task Role (for the application itself)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

# ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"   # 0.5 vCPU
  memory                   = "1024"  # 1 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([{
    name      = "web"
    image     = "${aws_ecr_repository.automation_ui.repository_url}:${var.docker_image_tag}"
    essential = true

    portMappings = [{
      containerPort = 5000
      protocol      = "tcp"
    }]

    environment = [
      {
        name  = "DB_HOST"
        value = aws_db_instance.automation_db.address
      },
      {
        name  = "DB_PORT"
        value = tostring(aws_db_instance.automation_db.port)
      },
      {
        name  = "DB_NAME"
        value = var.db_name
      },
      {
        name  = "AWS_REGION"
        value = var.aws_region
      },
      {
        name  = "COGNITO_DOMAIN"
        value = aws_cognito_user_pool_domain.main.domain
      },
      {
        name  = "COGNITO_USER_POOL_ID"
        value = aws_cognito_user_pool.main.id
      },
      {
        name  = "COGNITO_APP_CLIENT_ID"
        value = aws_cognito_user_pool_client.main.id
      },
      {
        name  = "ECS_CLUSTER_NAME"
        value = aws_ecs_cluster.main.name
      },
      {
        name  = "ECS_WORKER_TASK_DEFINITION"
        value = "${var.project_name}-worker"
      },
      {
        name  = "ECS_SUBNETS"
        value = "${aws_subnet.public.id},${aws_subnet.public_b.id}"
      },
      {
        name  = "ECS_SECURITY_GROUPS"
        value = aws_security_group.ecs_tasks.id
      },
      {
        name  = "USE_ECS_TASKS"
        value = "true"
      }
    ]

        secrets = [
          {
            name      = "DB_USER"
            valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:db_username::"
          },
          {
            name      = "DB_PASSWORD"
            valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:db_password::"
          },
          {
            name      = "SECRET_KEY"
            valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:secret_key::"
          }
        ]
    
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            "awslogs-group"         = "/ecs/${var.project_name}"
            "awslogs-region"        = var.aws_region
            "awslogs-stream-prefix" = "web"
            "awslogs-create-group"  = "true"
          }
        }

        healthCheck = {
          command     = ["CMD-SHELL", "curl -f http://localhost:5000/health || exit 1"]
          interval    = 30
          timeout     = 5
          retries     = 3
          startPeriod = 300
        }
      }])
  tags = {
    Name = "${var.project_name}-task-definition"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg"
  description = "Allow inbound traffic to ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-ecs-tasks-sg"
  }
}



# Create second public subnet for ALB (requires 2 AZs)


# ECS Service
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  enable_execute_command = true

  network_configuration {
    subnets          = [aws_subnet.public.id, aws_subnet.public_b.id]
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  depends_on = [aws_iam_role_policy.ecs_logs_policy]

  tags = {
    Name = "${var.project_name}-service"
  }
}

# Update DB security group to allow ECS tasks
resource "aws_security_group_rule" "db_from_ecs" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = aws_security_group.ecs_tasks.id
  description              = "Allow MySQL from ECS tasks"
}

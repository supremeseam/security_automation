# ECS Worker Task Definition for Script Execution
# Each script runs in its own isolated container

# Worker Task Definition
resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.project_name}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"   # 0.25 vCPU - lighter than web app
  memory                   = "512"   # 0.5 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_worker_task_role.arn

  container_definitions = jsonencode([{
    name      = "worker"
    image     = "${aws_ecr_repository.automation_ui.repository_url}:${var.docker_image_tag}"
    essential = true

    # Override command to run script
    # This will be overridden at runtime with specific script and parameters
    command = ["python3", "-c", "print('Worker container ready')"]

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
      }
    ]
  }])

  tags = {
    Name = "${var.project_name}-worker-task-definition"
  }
}

# IAM Role for Worker Tasks (with additional permissions for scripts)
resource "aws_iam_role" "ecs_worker_task_role" {
  name = "${var.project_name}-ecs-worker-task-role"

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

# Policy to allow workers to write results back to database or S3
resource "aws_iam_role_policy" "worker_permissions" {
  name = "${var.project_name}-worker-permissions"
  role = aws_iam_role.ecs_worker_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow writing to S3 if needed for large outputs
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Effect   = "Allow"
        Resource = "*"  # Restrict to specific bucket in production
      }
    ]
  })
}

# Update web app task role to allow launching worker tasks
resource "aws_iam_role_policy" "web_app_run_tasks" {
  name = "${var.project_name}-web-run-tasks"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecs:RunTask",
          "ecs:DescribeTasks",
          "ecs:StopTask"
        ]
        Effect = "Allow"
        Resource = [
          aws_ecs_task_definition.worker.arn,
          "arn:aws:ecs:${var.aws_region}:*:task/${aws_ecs_cluster.main.name}/*"
        ]
      },
      {
        Action = [
          "iam:PassRole"
        ]
        Effect = "Allow"
        Resource = [
          aws_iam_role.ecs_task_execution_role.arn,
          aws_iam_role.ecs_worker_task_role.arn
        ]
      }
    ]
  })
}

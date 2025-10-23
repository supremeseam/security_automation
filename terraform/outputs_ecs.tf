# ECS Deployment Outputs

output "alb_dns_name" {
  description = "The DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "ecs_application_url" {
  description = "The URL to access the Python Automation UI via ALB"
  value       = "http://${aws_lb.main.dns_name}"
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository"
  value       = aws_ecr_repository.automation_ui.repository_url
}

output "ecs_cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.app.name
}

# CloudWatch log group output removed due to IAM restrictions
# output "cloudwatch_log_group" {
#   description = "CloudWatch log group for ECS tasks"
#   value       = "/ecs/py-auto-ui"
# }

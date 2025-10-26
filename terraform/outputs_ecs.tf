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

output "application_access_instructions" {
  description = "Instructions to access the application."
  value       = <<EOT
To access the application, you need to find the public IP of the running ECS task.
1. Go to the AWS ECS console and navigate to the '${aws_ecs_cluster.main.name}' cluster.
2. Click on the '${aws_ecs_service.app.name}' service.
3. Go to the 'Tasks' tab and click on the running task.
4. In the 'Network' section, you will find the 'Public IP'.
5. The application will be available at http://<Public IP>:5000
EOT
}

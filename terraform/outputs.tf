output "application_url" {
  description = "The HTTPS URL to access the Python Automation UI."
  value       = "https://${var.domain_name}"
}

output "application_url_http" {
  description = "The HTTP URL (will redirect to HTTPS)."
  value       = "http://${var.domain_name}"
}

output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance (for DNS configuration)."
  value       = aws_instance.app_server.public_ip
}

output "dns_configuration" {
  description = "DNS configuration instructions for your domain registrar."
  value = <<-EOT
    Configure your DNS A record:

    Type: A
    Name: automation (subdomain)
    Value: ${aws_instance.app_server.public_ip}
    TTL: 300 (or default)

    Full domain: ${var.domain_name}
  EOT
}

output "ssh_command" {
  description = "Command to SSH into the EC2 instance."
  value       = "ssh -i ${local_file.private_key_pem.filename} ec2-user@${aws_instance.app_server.public_ip}"
}

output "private_key_path" {
  description = "Path to the generated private key file."
  value       = local_file.private_key_pem.filename
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_client_id" {
  description = "Cognito App Client ID"
  value       = aws_cognito_user_pool_client.app_client.id
}

output "cognito_domain" {
  description = "Cognito Hosted UI Domain"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
}

output "cognito_login_url" {
  description = "Cognito Hosted UI Login URL"
  value       = "https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.app_client.id}&response_type=code&scope=email+openid+profile&redirect_uri=https://${var.domain_name}/callback"
}

output "cognito_info" {
  description = "Cognito Configuration Summary"
  value = <<-EOT
    Cognito User Pool: ${aws_cognito_user_pool.main.id}
    App Client ID: ${aws_cognito_user_pool_client.app_client.id}
    Hosted UI Domain: ${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com

    Login URL: https://${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com/login?client_id=${aws_cognito_user_pool_client.app_client.id}&response_type=code&scope=email+openid+profile&redirect_uri=https://${var.domain_name}/callback

    Callback URLs configured:
    - https://${var.domain_name}/callback
    - https://${var.domain_name}/oauth2/callback
  EOT
}
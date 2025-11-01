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
output "application_url" {
  description = "The URL to access the Python Automation UI."
  value       = "http://${aws_instance.app_server.public_ip}:5000"
}

output "ssh_command" {
  description = "Command to SSH into the EC2 instance."
  value       = "ssh -i ${local_file.private_key_pem.filename} ec2-user@${aws_instance.app_server.public_ip}"
}

output "private_key_path" {
  description = "Path to the generated private key file."
  value       = local_file.private_key_pem.filename
}
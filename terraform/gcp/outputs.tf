output "application_url" {
  description = "The URL to access the application"
  value       = var.enable_ssl && var.domain_name != "" ? "https://${var.domain_name}" : "http://${google_compute_instance.app_server.network_interface[0].access_config[0].nat_ip}"
}

output "instance_public_ip" {
  description = "The public IP address of the Compute Engine instance"
  value       = google_compute_instance.app_server.network_interface[0].access_config[0].nat_ip
}

output "instance_private_ip" {
  description = "The private IP address of the Compute Engine instance"
  value       = google_compute_instance.app_server.network_interface[0].network_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ${local_file.private_key_pem.filename} automation-user@${google_compute_instance.app_server.network_interface[0].access_config[0].nat_ip}"
}

output "private_key_path" {
  description = "Path to the private SSH key file"
  value       = local_file.private_key_pem.filename
}

output "database_private_ip" {
  description = "The private IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.automation_db.private_ip_address
}

output "database_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.automation_db.connection_name
}

output "service_account_email" {
  description = "The email of the service account used by the app server"
  value       = google_service_account.app_server.email
}

output "ssl_status" {
  description = "SSL configuration status"
  value = var.enable_ssl ? (
    var.domain_name != "" && var.ssl_email != "" ?
    "SSL enabled for domain: ${var.domain_name}" :
    "SSL enabled but domain_name or ssl_email not set"
  ) : "SSL disabled - using HTTP only"
}

output "dns_instructions" {
  description = "DNS configuration instructions"
  value = var.enable_ssl && var.domain_name != "" ? "Point DNS A record for ${var.domain_name} to ${google_compute_instance.app_server.network_interface[0].access_config[0].nat_ip}" : "No SSL configured - DNS setup not required"
}

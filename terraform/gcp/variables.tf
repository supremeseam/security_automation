variable "gcp_project_id" {
  description = "The GCP project ID where resources will be created."
  type        = string
}

variable "gcp_region" {
  description = "The GCP region to deploy resources in."
  type        = string
  default     = "us-central1"
}

variable "gcp_zone_suffix" {
  description = "The zone suffix (a, b, c, etc.) within the region."
  type        = string
  default     = "a"
}

variable "project_name" {
  description = "A name for the project to prefix resource names."
  type        = string
  default     = "py-auto-ui"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet."
  type        = string
  default     = "10.0.2.0/24"
}

variable "instance_type" {
  description = "Compute Engine machine type for the app server."
  type        = string
  default     = "e2-micro"
}

variable "vm_image" {
  description = "The VM image to use for the Compute Engine instance."
  type        = string
  default     = "debian-cloud/debian-12"
}

variable "vm_disk_size" {
  description = "The size of the boot disk for the Compute Engine instance in GB."
  type        = number
  default     = 20
}

variable "db_instance_tier" {
  description = "Cloud SQL instance tier (machine type)."
  type        = string
  default     = "db-f1-micro"
}

variable "db_name" {
  description = "The name of the MySQL database."
  type        = string
  default     = "automation_ui"
}

variable "db_username" {
  description = "The master username for the Cloud SQL database."
  type        = string
  default     = "dbadmin"
}

variable "git_repo_url" {
  description = "The URL of the Git repository for the application."
  type        = string
  default     = "https://github.com/supremeseam/security_automation.git"
}

variable "domain_name" {
  description = "Domain name for SSL certificate (e.g., app.example.com). Leave empty to skip SSL setup."
  type        = string
  default     = ""
}

variable "ssl_email" {
  description = "Email address for Let's Encrypt SSL certificate notifications."
  type        = string
  default     = ""
}

variable "enable_ssl" {
  description = "Enable SSL/HTTPS with Let's Encrypt. Requires domain_name and ssl_email to be set."
  type        = bool
  default     = false
}

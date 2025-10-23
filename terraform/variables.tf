variable "aws_region" {
  description = "The AWS region to deploy resources in."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "A name for the project to prefix resource names."
  type        = string
  default     = "py-auto-ui"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
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

variable "private_subnet_cidr_2" {
  description = "CIDR block for the second private subnet in a different AZ."
  type        = string
  default     = "10.0.3.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the app server."
  type        = string
  default     = "t2.micro"
}

variable "db_instance_class" {
  description = "RDS instance class for the database."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "The name of the MySQL database."
  type        = string
  default     = "automation_ui"
}

variable "db_username" {
  description = "The master username for the RDS database."
  type        = string
  default     = "dbadmin"
}

variable "git_repo_url" {
  description = "The URL of the Git repository for the application."
  type        = string
  default     = "https://github.com/your-username/your-repo-name.git" # <-- IMPORTANT: CHANGE THIS
}
terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# Generate random passwords and secrets
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_string" "flask_secret" {
  length  = 32
  special = false
}

# VPC Network
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
}

# Public subnet for Compute Engine instance
resource "google_compute_subnetwork" "public" {
  name          = "${var.project_name}-public-subnet"
  ip_cidr_range = var.public_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.main.id

  # Enable private Google access for API calls
  private_ip_google_access = true
}

# Private subnet for Cloud SQL (optional - Cloud SQL can use auto-allocated IP)
resource "google_compute_subnetwork" "private" {
  name          = "${var.project_name}-private-subnet"
  ip_cidr_range = var.private_subnet_cidr
  region        = var.gcp_region
  network       = google_compute_network.main.id

  private_ip_google_access = true
}

# Firewall rule: Allow SSH (port 22)
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.project_name}-allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"] # WARNING: Open to the world. Restrict to your IP for production.
  target_tags   = ["${var.project_name}-app"]
}

# Firewall rule: Allow HTTP (port 80) - for Certbot verification
resource "google_compute_firewall" "allow_http" {
  name    = "${var.project_name}-allow-http"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.project_name}-app"]
}

# Firewall rule: Allow HTTPS (port 443)
resource "google_compute_firewall" "allow_https" {
  name    = "${var.project_name}-allow-https"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.project_name}-app"]
}

# Firewall rule: Allow Flask app (port 5000) - for direct access if needed
resource "google_compute_firewall" "allow_flask" {
  name    = "${var.project_name}-allow-flask"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["5000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["${var.project_name}-app"]
}

# Firewall rule: Allow all egress
resource "google_compute_firewall" "allow_egress" {
  name      = "${var.project_name}-allow-egress"
  network   = google_compute_network.main.name
  direction = "EGRESS"

  allow {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

# Private IP allocation for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.project_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

# Private VPC connection for Cloud SQL
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Cloud SQL MySQL Instance
resource "google_sql_database_instance" "automation_db" {
  name             = "${var.project_name}-db-${random_string.db_suffix.result}"
  database_version = "MYSQL_8_0"
  region           = var.gcp_region

  settings {
    tier              = var.db_instance_tier
    availability_type = "REGIONAL" # Multi-zone for high availability
    disk_size         = 20
    disk_type         = "PD_SSD"

    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }

    ip_configuration {
      ipv4_enabled    = false # No public IP
      private_network = google_compute_network.main.id
    }

    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = false

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Random suffix for unique database instance name
resource "random_string" "db_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Cloud SQL Database
resource "google_sql_database" "automation_db" {
  name     = var.db_name
  instance = google_sql_database_instance.automation_db.name
}

# Cloud SQL User
resource "google_sql_user" "db_user" {
  name     = var.db_username
  instance = google_sql_database_instance.automation_db.name
  password = random_password.db_password.result
}

# Secret Manager secrets
resource "google_secret_manager_secret" "db_password" {
  secret_id = "${var.project_name}-db-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_secret_manager_secret" "flask_secret" {
  secret_id = "${var.project_name}-flask-secret"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "flask_secret" {
  secret      = google_secret_manager_secret.flask_secret.id
  secret_data = random_string.flask_secret.result
}

resource "google_secret_manager_secret" "app_config" {
  secret_id = "${var.project_name}-app-config"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "app_config" {
  secret      = google_secret_manager_secret.app_config.id
  secret_data = jsonencode({
    db_host      = google_sql_database_instance.automation_db.private_ip_address
    db_port      = "3306"
    db_name      = var.db_name
    db_username  = var.db_username
    db_password  = random_password.db_password.result
    secret_key   = random_string.flask_secret.result
    git_repo_url = var.git_repo_url
    domain       = var.domain_name
    ssl_email    = var.ssl_email
  })
}

# Service Account for Compute Engine
resource "google_service_account" "app_server" {
  account_id   = "${var.project_name}-app-sa"
  display_name = "Service Account for ${var.project_name} Application Server"
}

# IAM: Allow service account to access Secret Manager
resource "google_secret_manager_secret_iam_member" "app_config_access" {
  secret_id = google_secret_manager_secret.app_config.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_server.email}"
}

resource "google_secret_manager_secret_iam_member" "db_password_access" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_server.email}"
}

resource "google_secret_manager_secret_iam_member" "flask_secret_access" {
  secret_id = google_secret_manager_secret.flask_secret.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app_server.email}"
}

# IAM: Allow service account to log to Cloud Logging
resource "google_project_iam_member" "app_server_logging" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app_server.email}"
}

# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally
resource "local_file" "private_key_pem" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/${var.project_name}-key.pem"
  file_permission = "0400"
}

# Compute Engine Instance
resource "google_compute_instance" "app_server" {
  name         = "${var.project_name}-app-server"
  machine_type = var.instance_type
  zone         = "${var.gcp_region}-${var.gcp_zone_suffix}"

  tags = ["${var.project_name}-app"]

  boot_disk {
    initialize_params {
      image = var.vm_image
      size  = var.vm_disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = google_compute_network.main.id
    subnetwork = google_compute_subnetwork.public.id

    # Assign public IP
    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    ssh-keys = "automation-user:${tls_private_key.ssh_key.public_key_openssh}"
  }

  metadata_startup_script = templatefile("${path.module}/startup_script.sh", {
    secret_name  = google_secret_manager_secret.app_config.secret_id
    gcp_project  = var.gcp_project_id
    app_dir      = "/opt/automation-ui"
    db_host      = google_sql_database_instance.automation_db.private_ip_address
    db_name      = var.db_name
    db_username  = var.db_username
    domain_name  = var.domain_name
    ssl_email    = var.ssl_email
    enable_ssl   = var.enable_ssl
  })

  service_account {
    email  = google_service_account.app_server.email
    scopes = ["cloud-platform"]
  }

  depends_on = [
    google_secret_manager_secret_version.app_config,
    google_sql_database_instance.automation_db,
    google_sql_database.automation_db,
    google_sql_user.db_user
  ]
}

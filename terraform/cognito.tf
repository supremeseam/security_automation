# AWS Cognito User Pool for Authentication

resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-user-pool"

  # Allow users to sign in with username or email
  alias_attributes = ["email", "preferred_username"]
  auto_verified_attributes = ["email"]

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_uppercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # Account recovery settings
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User attributes
  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  schema {
    name                = "name"
    attribute_data_type = "String"
    required            = false
    mutable             = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Email configuration
  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

  # MFA configuration (optional but recommended)
  mfa_configuration = "OPTIONAL"

  software_token_mfa_configuration {
    enabled = true
  }

  # User pool add-ons
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  tags = {
    Name = "${var.project_name}-user-pool"
  }
}

# Cognito User Pool Client (Application)
resource "aws_cognito_user_pool_client" "app_client" {
  name         = "${var.project_name}-app-client"
  user_pool_id = aws_cognito_user_pool.main.id

  # OAuth flows
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Callback URLs (application endpoints)
  callback_urls = [
    "https://${var.domain_name}/callback",
    "https://${var.domain_name}/oauth2/callback",
    "http://localhost:5000/callback" # For local development
  ]

  # Logout URLs
  logout_urls = [
    "https://${var.domain_name}/logout",
    "https://${var.domain_name}",
    "http://localhost:5000/logout"
  ]

  # Token validity
  id_token_validity      = 60  # minutes
  access_token_validity  = 60  # minutes
  refresh_token_validity = 30  # days

  token_validity_units {
    id_token      = "minutes"
    access_token  = "minutes"
    refresh_token = "days"
  }

  # Enable refresh token rotation
  enable_token_revocation = true

  # Prevent client secret (for public web apps)
  generate_secret = false

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]

  # Read and write attributes
  read_attributes = [
    "email",
    "email_verified",
    "name",
    "preferred_username"
  ]

  write_attributes = [
    "email",
    "name",
    "preferred_username"
  ]
}

# Cognito User Pool Domain
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-auth-${random_string.cognito_domain_suffix.result}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Random suffix for Cognito domain (must be globally unique)
resource "random_string" "cognito_domain_suffix" {
  length  = 8
  special = false
  upper   = false
}

# Store Cognito configuration in Secrets Manager
resource "aws_secretsmanager_secret_version" "cognito_config" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    db_password       = random_password.db_password.result
    secret_key        = random_string.flask_secret.result
    db_username       = var.db_username
    db_name           = var.db_name
    db_host           = aws_db_instance.automation_db.address
    db_port           = aws_db_instance.automation_db.port
    git_repo_url      = var.git_repo_url
    cognito_user_pool_id     = aws_cognito_user_pool.main.id
    cognito_client_id        = aws_cognito_user_pool_client.app_client.id
    cognito_domain           = "${aws_cognito_user_pool_domain.main.domain}.auth.${var.aws_region}.amazoncognito.com"
    cognito_region           = var.aws_region
    app_domain               = var.domain_name
  })

  lifecycle {
    ignore_changes = [secret_string]
  }

  depends_on = [
    aws_secretsmanager_secret_version.app_secrets_version
  ]
}

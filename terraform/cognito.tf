resource "aws_cognito_user_pool" "user_pool" {
  name = "automation_user_pool"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  # Email configuration
  auto_verified_attributes = ["email"]

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = {
    Name = "${var.project_name}-user-pool"
  }
}

resource "aws_cognito_user_pool_domain" "user_pool_domain" {
  domain       = "${var.project_name}-auth-${substr(md5(aws_cognito_user_pool.user_pool.id), 0, 8)}"
  user_pool_id = aws_cognito_user_pool.user_pool.id
}

resource "aws_cognito_user_pool_client" "user_pool_client" {
  name         = "${var.project_name}-app-client"
  user_pool_id = aws_cognito_user_pool.user_pool.id

  # OAuth settings
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  # Callback URLs - uses HTTPS ALB URL when certificate is configured
  callback_urls = var.acm_certificate_arn != "" ? [
    "http://localhost:5000/callback",
    "https://${aws_lb.main.dns_name}/callback"
  ] : [
    "http://localhost:5000/callback"
  ]

  logout_urls = var.acm_certificate_arn != "" ? [
    "http://localhost:5000/login",
    "https://${aws_lb.main.dns_name}/login"
  ] : [
    "http://localhost:5000/login"
  ]

  # Token validity
  access_token_validity  = 60  # minutes
  id_token_validity      = 60  # minutes
  refresh_token_validity = 30  # days

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # Supported identity providers
  supported_identity_providers = ["COGNITO"]

  # Prevent secret generation for public clients
  generate_secret = false

  # Attribute read/write permissions
  read_attributes  = ["email", "email_verified", "name"]
  write_attributes = ["email", "name"]
}
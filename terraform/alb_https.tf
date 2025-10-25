# HTTPS Configuration for ALB
#
# IMPORTANT: You need to choose ONE of these options:
#
# OPTION 1 (Recommended): Use a custom domain
#   - Uncomment the aws_acm_certificate block below
#   - Set the domain_name variable in terraform.tfvars
#   - Ensure you have Route53 hosted zone or can add DNS records
#
# OPTION 2 (Quick Test): Use AWS-managed certificate for ALB DNS
#   - Request a certificate manually in ACM console
#   - Use the ALB DNS name as the domain
#   - Import the certificate ARN as a variable
#
# For now, this file provides the structure.
# Uncomment and configure based on your domain situation.

# OPTION 1: ACM Certificate with Custom Domain (RECOMMENDED)
# Uncomment this block if you have a custom domain

# variable "domain_name" {
#   description = "Custom domain name for the application (e.g., app.example.com)"
#   type        = string
#   default     = ""  # Set this in terraform.tfvars
# }

# data "aws_route53_zone" "domain" {
#   count = var.domain_name != "" ? 1 : 0
#   name  = var.domain_name
# }

# resource "aws_acm_certificate" "alb_cert" {
#   count             = var.domain_name != "" ? 1 : 0
#   domain_name       = var.domain_name
#   validation_method = "DNS"
#
#   lifecycle {
#     create_before_destroy = true
#   }
#
#   tags = {
#     Name = "${var.project_name}-alb-certificate"
#   }
# }
#
# resource "aws_route53_record" "cert_validation" {
#   for_each = var.domain_name != "" ? {
#     for dvo in aws_acm_certificate.alb_cert[0].domain_validation_options : dvo.domain_name => {
#       name   = dvo.resource_record_name
#       record = dvo.resource_record_value
#       type   = dvo.resource_record_type
#     }
#   } : {}
#
#   allow_overwrite = true
#   name            = each.value.name
#   records         = [each.value.record]
#   ttl             = 60
#   type            = each.value.type
#   zone_id         = data.aws_route53_zone.domain[0].zone_id
# }
#
# resource "aws_acm_certificate_validation" "alb_cert" {
#   count                   = var.domain_name != "" ? 1 : 0
#   certificate_arn         = aws_acm_certificate.alb_cert[0].arn
#   validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
# }

# OPTION 2: Use manually created certificate
# Create a certificate manually in ACM and provide the ARN

variable "acm_certificate_arn" {
  description = "ARN of manually created ACM certificate (leave empty to skip HTTPS)"
  type        = string
  default     = ""
}

# HTTPS Listener (Port 443) - Only created if certificate ARN is provided
resource "aws_lb_listener" "app_https" {
  count             = var.acm_certificate_arn != "" ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.acm_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Optional: HTTP to HTTPS redirect (only if HTTPS is enabled)
# Uncomment if you want HTTP traffic to redirect to HTTPS

# resource "aws_lb_listener" "app_http_redirect" {
#   count             = var.acm_certificate_arn != "" ? 1 : 0
#   load_balancer_arn = aws_lb.main.arn
#   port              = "80"
#   protocol          = "HTTP"
#
#   default_action {
#     type = "redirect"
#
#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }
# }

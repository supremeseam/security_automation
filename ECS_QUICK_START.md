# ECS Quick Start - 5 Minute Deploy

Get your application running on ECS in 5 minutes!

## ⚡ Quick Deploy Steps

### 1. Deploy Infrastructure (2 minutes)

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

**What this creates:**
- ECR repository for Docker images
- ECS cluster with Fargate
- Application Load Balancer
- All necessary networking and security

### 2. Build & Push Docker Image (2 minutes)

**Windows (PowerShell):**
```powershell
.\build-and-push.ps1
```

**Linux/Mac:**
```bash
chmod +x build-and-push.sh
./build-and-push.sh
```

### 3. Access Your Application (1 minute)

```bash
# Get the URL
terraform output ecs_application_url

# Or manually:
terraform output alb_dns_name
```

Open browser to: `http://<alb-dns-name>`

**Done!** Your app is now running on ECS! 🎉

---

## 📊 What You Get

| Feature | Details |
|---------|---------|
| **Deployment** | Fully managed Fargate (no servers to manage) |
| **Scaling** | Manual (can add auto-scaling later) |
| **High Availability** | Load balancer across 2 AZs |
| **Monitoring** | CloudWatch logs and Container Insights |
| **Security** | Private networking, IAM roles, Secrets Manager |
| **Cost** | ~$35/month minimum (1 task + ALB) |

---

## 🔄 Making Updates

When you change code:

```bash
# 1. Push image
.\build-and-push.ps1

# 2. Deploy new version
aws ecs update-service --cluster py-auto-ui-cluster --service py-auto-ui-service --force-new-deployment --region us-east-1

# 3. Wait ~2 minutes for rolling deployment
```

---

## 📝 View Logs

```bash
aws logs tail /ecs/py-auto-ui --follow
```

---

## 🛑 To Disable EC2 Instance (Optional)

If you want to stop paying for the EC2 instance and only use ECS:

1. Comment out in `terraform/main.tf`:
   - Lines 208-222: `tls_private_key`, `aws_key_pair`, `local_file`
   - Lines 224-245: `aws_instance.app_server`

2. Comment out in `terraform/outputs.tf`:
   - Old EC2 outputs

3. Run:
   ```bash
   terraform apply
   ```

Or keep both running during migration!

---

## 💰 Cost Comparison

| Option | Monthly Cost | Pros | Cons |
|--------|--------------|------|------|
| **Current EC2** | ~$66 | Simple, instant start | Single point of failure |
| **ECS Fargate** | ~$35 | Managed, HA, scalable | Small cold start delay |
| **Both** | ~$101 | Zero downtime migration | Higher cost temporarily |

---

## ❓ Troubleshooting

### Tasks not starting?
```bash
# Check task status
aws ecs describe-tasks --cluster py-auto-ui-cluster --tasks $(aws ecs list-tasks --cluster py-auto-ui-cluster --service py-auto-ui-service --query 'taskArns[0]' --output text) --region us-east-1

# Check logs
aws logs tail /ecs/py-auto-ui --follow
```

### Can't access via ALB?
```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw alb_target_group_arn)

# Wait for health checks (can take 2-3 minutes)
```

### Image not found?
```bash
# Verify image was pushed
aws ecr describe-images --repository-name py-auto-ui-app --region us-east-1
```

---

## 📚 Full Documentation

See [ECS_DEPLOYMENT.md](ECS_DEPLOYMENT.md) for:
- Detailed architecture
- Advanced configuration
- Monitoring and alerting
- CI/CD integration
- Auto-scaling setup
- Cost optimization

---

## 🎯 Next Steps

1. ✅ Deploy to ECS (you just did this!)
2. [ ] Set up custom domain (Route 53 + ACM)
3. [ ] Add HTTPS certificate
4. [ ] Configure auto-scaling
5. [ ] Set up CloudWatch alarms
6. [ ] Implement CI/CD pipeline

---

## Need Help?

1. Check [ECS_DEPLOYMENT.md](ECS_DEPLOYMENT.md) troubleshooting section
2. View logs: `aws logs tail /ecs/py-auto-ui --follow`
3. Check ECS console: https://console.aws.amazon.com/ecs/

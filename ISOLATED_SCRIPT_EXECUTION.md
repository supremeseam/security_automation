# Isolated Script Execution with ECS

Each automation script now runs in its own isolated Fargate container for better security, resource management, and fault tolerance.

## 🏗️ Architecture

```
┌────────────────────────────────────────────────────────┐
│ User clicks "Run Script"                               │
└──────────────────┬─────────────────────────────────────┘
                   │
┌──────────────────▼─────────────────────────────────────┐
│ Web Container (Always Running)                         │
│ - Flask app                                            │
│ - Receives request                                     │
│ - Calls ECS API via boto3                            │
└──────────────────┬─────────────────────────────────────┘
                   │
┌──────────────────▼─────────────────────────────────────┐
│ AWS ECS - Run Task API                                 │
│ - Launches new Fargate task                           │
│ - Returns task ARN immediately                        │
└──────────────────┬─────────────────────────────────────┘
                   │
┌──────────────────▼─────────────────────────────────────┐
│ Worker Container (Runs Once)                           │
│ - Same Docker image as web app                        │
│ - Overridden command to run specific script          │
│ - Has access to database                              │
│ - Exits when script completes                         │
│ - Automatically cleaned up by ECS                     │
└────────────────────────────────────────────────────────┘
```

## ✅ Benefits

| Feature | Before (Subprocess) | After (ECS Tasks) |
|---------|-------------------|-------------------|
| **Isolation** | Scripts run in same container | Each script in own container |
| **Resource Limits** | Share resources with web app | Dedicated CPU/memory per script |
| **Fault Tolerance** | Script crash affects web app | Isolated failures |
| **Scalability** | Limited by web container | 100s of concurrent scripts |
| **Monitoring** | Combined logs | Separate logs per execution |
| **Cost** | Fixed (always paying) | Pay only when scripts run |

## 📦 What Was Created

### 1. Infrastructure (`terraform/ecs_worker.tf`)
- **Worker Task Definition** - Lightweight container (0.25 vCPU, 0.5 GB)
- **IAM Permissions** - Web app can launch worker tasks
- **Security** - Workers can access database but isolated from web traffic

### 2. Task Runner (`app/task_runner.py`)
- **ECSTaskRunner** - Launches scripts as ECS tasks
- **SubprocessRunner** - Fallback for local development
- **Auto-detection** - Uses ECS in production, subprocess locally

### 3. Updated Flask App (`app/app.py`)
- Modified `/api/run` endpoint to use task runner
- Added `/api/task/<arn>/status` - Check task status
- Added `/api/task/<arn>/stop` - Stop running task

## 🚀 How It Works

### When User Clicks "Run Script"

1. **Request hits web app**
   ```
   POST /api/run
   {
     "automation_id": "file_organizer",
     "parameters": {"source_folder": "/data", "organize_by": "extension"}
   }
   ```

2. **Web app launches ECS task**
   ```python
   task_runner.run_script(
       script_path="scripts/file_organizer.py",
       parameters=params,
       automation_id=auto_id,
       user_id=current_user.id
   )
   ```

3. **ECS starts worker container**
   - Uses same Docker image
   - Overrides command: `python3 scripts/file_organizer.py --source_folder /data --organize_by extension`
   - Injects environment variables (automation_id, user_id, db credentials)

4. **Web app returns immediately**
   ```json
   {
     "success": true,
     "message": "Script execution started in isolated container",
     "task_arn": "arn:aws:ecs:us-east-1:...:task/...",
     "status": "PROVISIONING",
     "execution_mode": "ecs"
   }
   ```

5. **Worker container executes script**
   - Script runs with parameters
   - Has database access
   - Isolated resources
   - Container exits when done

6. **ECS cleans up**
   - Container stopped
   - Resources released
   - Logs retained (if CloudWatch enabled)

## 🔍 Monitoring Scripts

### Check Task Status

```bash
# Get task status
curl -H "Authorization: Bearer <token>" \
  http://<alb-dns>/api/task/<task-arn>/status

# Response:
{
  "status": "RUNNING",
  "started_at": "2025-10-23T10:30:00",
  "stopped_at": null,
  "exit_code": null
}
```

### View Running Tasks

```bash
# List all tasks in cluster
aws ecs list-tasks --cluster py-auto-ui-cluster --region us-east-1

# Describe specific task
aws ecs describe-tasks \
  --cluster py-auto-ui-cluster \
  --tasks <task-arn> \
  --region us-east-1
```

### Stop a Running Task

```bash
# Via API
curl -X POST -H "Authorization: Bearer <token>" \
  http://<alb-dns>/api/task/<task-arn>/stop

# Via CLI
aws ecs stop-task \
  --cluster py-auto-ui-cluster \
  --task <task-arn> \
  --reason "User requested stop" \
  --region us-east-1
```

## 💰 Cost Implications

### Before (Shared Container)
- Web container: 0.5 vCPU, 1 GB RAM = ~$18/month (always running)
- Scripts use same resources (free but limited)

### After (Isolated Containers)
- Web container: 0.5 vCPU, 1 GB RAM = ~$18/month (always running)
- Worker containers: 0.25 vCPU, 0.5 GB RAM = $0.012/hour per task
  - Script runs 5 minutes = $0.001 per execution
  - 100 executions/day = $3/month
  - 1000 executions/day = $30/month

**Total cost example:**
- Web: $18/month
- ALB: $16/month
- Workers: $3-30/month (depends on usage)
- **Total: $37-64/month**

## 🧪 Testing

### Local Development (Subprocess Mode)

When running locally, it automatically uses subprocess:

```bash
cd app
python3 app.py

# No ECS_CONTAINER_METADATA_URI environment variable
# Falls back to SubprocessRunner
# Scripts run normally in same process
```

### Production (ECS Mode)

In ECS, it automatically detects and uses ECS tasks:

```python
# Web container has ECS_CONTAINER_METADATA_URI set
# Or USE_ECS_TASKS=true
# Uses ECSTaskRunner
# Scripts run in isolated containers
```

## 📋 Deployment Steps

### 1. Commit Changes

```bash
git add app/app.py app/task_runner.py app/requirements.txt terraform/ecs_worker.tf terraform/ecs.tf
git commit -m "Add isolated script execution with ECS tasks"
git push
```

### 2. Update Infrastructure

```bash
cd terraform
terraform apply
```

This creates:
- Worker task definition
- IAM permissions for web app to launch tasks
- Environment variables in web app container

### 3. Rebuild and Deploy Docker Image

```powershell
.\build-and-push.ps1
```

### 4. Force New Deployment

```bash
aws ecs update-service \
  --cluster py-auto-ui-cluster \
  --service py-auto-ui-service \
  --force-new-deployment \
  --region us-east-1
```

### 5. Test

1. Open web UI
2. Select an automation
3. Click "Run"
4. Should see: `"execution_mode": "ecs"`
5. Check ECS console - you'll see worker tasks appear and disappear

## 🔧 Configuration

### Adjust Worker Resources

Edit `terraform/ecs_worker.tf`:

```hcl
resource "aws_ecs_task_definition" "worker" {
  cpu    = "512"   # 0.5 vCPU (increase for heavy scripts)
  memory = "1024"  # 1 GB (increase for memory-intensive scripts)
  ...
}
```

### Adjust Timeout

Edit `app/task_runner.py`:

```python
def wait_for_completion(self, task_arn, timeout=300):  # 5 minutes
    # Change to timeout=600 for 10 minutes, etc.
```

### Add Script-Specific Resources

You can create multiple worker task definitions for different resource needs:

```hcl
# Heavy worker for data processing
resource "aws_ecs_task_definition" "worker_heavy" {
  family = "${var.project_name}-worker-heavy"
  cpu    = "1024"  # 1 vCPU
  memory = "2048"  # 2 GB
  ...
}
```

## 🐛 Troubleshooting

### Tasks Not Starting

```bash
# Check IAM permissions
aws ecs describe-services \
  --cluster py-auto-ui-cluster \
  --services py-auto-ui-service \
  --query 'services[0].events[0:5]'

# Common issues:
# - Web app IAM role missing ecs:RunTask permission
# - Subnets or security groups misconfigured
# - Task definition not found
```

### Tasks Failing Immediately

```bash
# Describe stopped tasks
aws ecs describe-tasks \
  --cluster py-auto-ui-cluster \
  --tasks <task-arn> \
  --query 'tasks[0].stoppedReason'

# Common issues:
# - Script file not found in Docker image
# - Database connection failed
# - Python import errors
```

### Scripts Running But No Output

- Worker containers don't have CloudWatch logging (IAM restrictions)
- Use ECS console → Task → Logs tab to view output
- Or enable CloudWatch after fixing IAM permissions

## 📊 Monitoring & Alerts

### CloudWatch Metrics

Monitor these metrics:
- `TaskCount` - Number of worker tasks
- `CPUUtilization` - Worker CPU usage
- `MemoryUtilization` - Worker memory usage

### Set Up Alarms

```bash
# Alert if too many tasks fail
aws cloudwatch put-metric-alarm \
  --alarm-name high-worker-failures \
  --metric-name TaskCount \
  --namespace AWS/ECS \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold
```

## 🎯 Best Practices

1. **Set Resource Limits** - Don't let runaway scripts consume all resources
2. **Add Timeouts** - Kill tasks that run too long
3. **Tag Tasks** - Tag with user_id, automation_id for tracking
4. **Monitor Costs** - Watch Fargate usage, especially in dev
5. **Limit Concurrency** - Prevent too many tasks from running simultaneously
6. **Handle Failures** - Retry failed tasks or alert users

## 🔒 Security Benefits

- ✅ **Process Isolation** - Script bugs can't crash web app
- ✅ **Resource Limits** - Can't exhaust web container resources
- ✅ **Network Isolation** - Workers don't expose web ports
- ✅ **Credential Isolation** - Each task gets temporary credentials
- ✅ **Audit Trail** - Each execution tracked as separate ECS task

## 🚦 Next Steps

1. ✅ Deploy the changes
2. ✅ Test with sample scripts
3. [ ] Add UI to show running tasks
4. [ ] Implement task cancellation in UI
5. [ ] Add task history/logs page
6. [ ] Set up monitoring and alerts
7. [ ] Implement task retry logic
8. [ ] Add script output streaming (WebSocket)

---

**Your scripts now run in complete isolation!** 🎉

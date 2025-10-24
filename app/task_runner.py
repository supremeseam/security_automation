"""
ECS Task Runner for Isolated Script Execution
Launches scripts in their own Fargate containers
"""
import boto3
import json
import time
from datetime import datetime
import os

class ECSTaskRunner:
    def __init__(self):
        self.ecs_client = boto3.client('ecs', region_name=os.getenv('AWS_REGION', 'us-east-1'))
        self.cluster_name = os.getenv('ECS_CLUSTER_NAME', 'py-auto-ui-cluster')
        self.task_definition = os.getenv('ECS_WORKER_TASK_DEFINITION', 'py-auto-ui-worker')
        self.subnets = os.getenv('ECS_SUBNETS', '').split(',')  # Will be set via env var
        self.security_groups = os.getenv('ECS_SECURITY_GROUPS', '').split(',')

    def run_script(self, script_path, parameters, automation_id, user_id):
        """
        Launch a script in its own ECS task

        Args:
            script_path: Path to the script (e.g., "scripts/file_organizer.py")
            parameters: Dict of parameters for the script
            automation_id: ID of the automation
            user_id: User who triggered the automation

        Returns:
            dict: {
                'task_arn': 'arn:aws:ecs:...',
                'status': 'PROVISIONING',
                'started_at': '2025-...'
            }
        """
        # Build command with parameters
        command = self._build_command(script_path, parameters)

        # Override container command
        overrides = {
            'containerOverrides': [{
                'name': 'worker',
                'command': command,
                'environment': [
                    {'name': 'AUTOMATION_ID', 'value': str(automation_id)},
                    {'name': 'USER_ID', 'value': str(user_id)},
                    {'name': 'STARTED_AT', 'value': datetime.now().isoformat()}
                ]
            }]
        }

        try:
            response = self.ecs_client.run_task(
                cluster=self.cluster_name,
                taskDefinition=self.task_definition,
                launchType='FARGATE',
                networkConfiguration={
                    'awsvpcConfiguration': {
                        'subnets': self.subnets,
                        'securityGroups': self.security_groups,
                        'assignPublicIp': 'ENABLED'
                    }
                },
                overrides=overrides,
                tags=[
                    {'key': 'AutomationId', 'value': str(automation_id)},
                    {'key': 'UserId', 'value': str(user_id)},
                    {'key': 'ScriptPath', 'value': script_path}
                ]
            )

            if response['tasks']:
                task = response['tasks'][0]
                return {
                    'success': True,
                    'task_arn': task['taskArn'],
                    'status': task['lastStatus'],
                    'started_at': datetime.now().isoformat(),
                    'cluster': self.cluster_name
                }
            else:
                return {
                    'success': False,
                    'error': 'Failed to start task',
                    'failures': response.get('failures', [])
                }

        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }

    def _build_command(self, script_path, parameters):
        """Build the command array for running the script"""
        command = ['python3', script_path]

        # Add parameters as command-line arguments
        for key, value in parameters.items():
            if isinstance(value, bool):
                if value:
                    command.append(f'--{key}')
            else:
                command.extend([f'--{key}', str(value)])

        return command

    def get_task_status(self, task_arn):
        """
        Get the status of a running task

        Returns:
            dict: {
                'status': 'RUNNING',
                'started_at': '...',
                'stopped_at': '...',
                'stop_reason': '...',
                'exit_code': 0
            }
        """
        try:
            response = self.ecs_client.describe_tasks(
                cluster=self.cluster_name,
                tasks=[task_arn]
            )

            if response['tasks']:
                task = response['tasks'][0]
                result = {
                    'status': task['lastStatus'],
                    'desired_status': task.get('desiredStatus'),
                    'started_at': task.get('startedAt', '').isoformat() if task.get('startedAt') else None,
                    'stopped_at': task.get('stoppedAt', '').isoformat() if task.get('stoppedAt') else None,
                    'stop_reason': task.get('stoppedReason'),
                }

                # Get exit code from container
                if task.get('containers'):
                    container = task['containers'][0]
                    result['exit_code'] = container.get('exitCode')

                return result
            else:
                return {'status': 'NOT_FOUND'}

        except Exception as e:
            return {'status': 'ERROR', 'error': str(e)}

    def stop_task(self, task_arn, reason='User requested stop'):
        """Stop a running task"""
        try:
            response = self.ecs_client.stop_task(
                cluster=self.cluster_name,
                task=task_arn,
                reason=reason
            )
            return {'success': True, 'task': response['task']}
        except Exception as e:
            return {'success': False, 'error': str(e)}

    def wait_for_completion(self, task_arn, timeout=300):
        """
        Wait for a task to complete (blocking)

        Args:
            task_arn: Task ARN to wait for
            timeout: Maximum seconds to wait

        Returns:
            dict: Final task status
        """
        start_time = time.time()

        while time.time() - start_time < timeout:
            status = self.get_task_status(task_arn)

            if status['status'] in ['STOPPED', 'NOT_FOUND', 'ERROR']:
                return status

            time.sleep(5)  # Poll every 5 seconds

        return {'status': 'TIMEOUT', 'error': 'Task did not complete within timeout'}


# Fallback to subprocess if not running in ECS
class SubprocessRunner:
    """Fallback runner for local development"""
    def run_script(self, script_path, parameters, automation_id, user_id):
        import subprocess
        from pathlib import Path

        script = Path(__file__).parent / script_path
        if not script.exists():
            return {
                'success': False,
                'error': f'Script not found: {script_path}'
            }

        cmd = ['python3', str(script)]
        for key, value in parameters.items():
            if isinstance(value, bool):
                if value:
                    cmd.append(f'--{key}')
            else:
                cmd.extend([f'--{key}', str(value)])

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            return {
                'success': result.returncode == 0,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'exit_code': result.returncode
            }
        except Exception as e:
            return {
                'success': False,
                'error': str(e)
            }


# Auto-detect environment and use appropriate runner
def get_task_runner():
    """
    Returns ECS task runner if in ECS, otherwise subprocess runner
    """
    # Check if running in ECS (ECS sets these environment variables)
    if os.getenv('ECS_CONTAINER_METADATA_URI') or os.getenv('USE_ECS_TASKS') == 'true':
        return ECSTaskRunner()
    else:
        return SubprocessRunner()

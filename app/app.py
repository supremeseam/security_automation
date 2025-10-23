from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
from flask_cors import CORS
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
import mysql.connector
import bcrypt
import json
import os
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv
from task_runner import get_task_runner

load_dotenv()

# Initialize task runner (ECS or subprocess based on environment)
task_runner = get_task_runner()

app = Flask(__name__, static_folder='static', template_folder='templates')
app.secret_key = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
CORS(app)

DB_CONFIG = {
    'host': os.getenv('DB_HOST', '10.20.72.84'),
    'port': int(os.getenv('DB_PORT', 3306)),
    'database': os.getenv('DB_NAME', 'automation_ui'),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', '')
}

login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

def get_db():
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Exception as e:
        print(f"DB connection failed: {e}")
        return None

class User(UserMixin):
    def __init__(self, id, username, email, full_name):
        self.id = id
        self.username = username
        self.email = email
        self.full_name = full_name

@login_manager.user_loader
def load_user(user_id):
    db = get_db()
    if not db:
        return None

    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT id, username, email, full_name FROM users WHERE id = %s AND is_active = TRUE", (user_id,))
    user_data = cursor.fetchone()
    cursor.close()
    db.close()

    if user_data:
        return User(user_data['id'], user_data['username'], user_data['email'], user_data['full_name'])
    return None

def verify_user(username, password):
    db = get_db()
    if not db:
        return None

    cursor = db.cursor(dictionary=True)
    cursor.execute("SELECT id, username, password_hash, email, full_name FROM users WHERE username = %s AND is_active = TRUE", (username,))
    user = cursor.fetchone()

    if user and bcrypt.checkpw(password.encode(), user['password_hash'].encode()):
        cursor.execute("UPDATE users SET last_login = %s WHERE id = %s", (datetime.now(), user['id']))
        db.commit()
        cursor.close()
        db.close()
        return User(user['id'], user['username'], user['email'], user['full_name'])

    if cursor:
        cursor.close()
    if db:
        db.close()
    return None

def load_config():
    with open(Path(__file__).parent / 'config' / 'automations_config.json') as f:
        return json.load(f)

def log_run(user_id, auto_id, auto_name, params, success, output, exec_time):
    db = get_db()
    if not db:
        return

    try:
        cursor = db.cursor()
        cursor.execute(
            "INSERT INTO automation_logs (user_id, automation_id, automation_name, parameters, success, output, execution_time) VALUES (%s, %s, %s, %s, %s, %s, %s)",
            (user_id, auto_id, auto_name, json.dumps(params), success, output, exec_time)
        )
        db.commit()
        cursor.close()
        db.close()
    except Exception as e:
        print(f"Logging failed: {e}")

@app.route('/health')
def health_check():
    """Health check endpoint for ALB"""
    return jsonify({'status': 'healthy'}), 200

@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('index'))

    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')

        if not username or not password:
            flash('Username and password required', 'error')
            return render_template('login.html')

        user = verify_user(username, password)
        if user:
            login_user(user)
            return redirect(request.args.get('next') or url_for('index'))

        flash('Invalid credentials', 'error')

    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    flash('Logged out', 'success')
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    return render_template('index.html', user=current_user)

@app.route('/api/automations')
@login_required
def get_automations():
    try:
        return jsonify(load_config()['automations'])
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/run', methods=['POST'])
@login_required
def run_automation():
    """Run automation script in isolated container (ECS) or subprocess (local dev)"""
    start = datetime.now()
    try:
        data = request.json
        auto_id = data.get('automation_id')
        params = data.get('parameters', {})

        config = load_config()
        automation = next((a for a in config['automations'] if a['id'] == auto_id), None)

        if not automation:
            return jsonify({'error': 'Automation not found'}), 404

        # Launch script in isolated container
        result = task_runner.run_script(
            script_path=automation['script'],
            parameters=params,
            automation_id=auto_id,
            user_id=current_user.id
        )

        if not result.get('success'):
            # Task failed to launch
            exec_time = (datetime.now() - start).total_seconds()
            log_run(current_user.id, auto_id, automation['name'], params,
                    False, result.get('error', 'Unknown error'), exec_time)
            return jsonify(result), 500

        # For ECS tasks, return immediately with task info
        # Client can poll for status
        if 'task_arn' in result:
            return jsonify({
                'success': True,
                'message': 'Script execution started in isolated container',
                'task_arn': result['task_arn'],
                'status': result['status'],
                'execution_mode': 'ecs'
            })
        else:
            # Subprocess mode (local dev) - returns immediately with result
            exec_time = (datetime.now() - start).total_seconds()
            log_run(current_user.id, auto_id, automation['name'], params,
                    result.get('success', False),
                    result.get('stdout', '') or result.get('stderr', ''),
                    exec_time)

            return jsonify({
                'success': result.get('success', False),
                'stdout': result.get('stdout'),
                'stderr': result.get('stderr'),
                'execution_mode': 'subprocess'
            })

    except Exception as e:
        exec_time = (datetime.now() - start).total_seconds()
        log_run(current_user.id, auto_id if 'auto_id' in locals() else 'unknown',
                'Unknown', params if 'params' in locals() else {}, False, str(e), exec_time)
        return jsonify({'error': str(e)}), 500

@app.route('/api/task/<path:task_arn>/status', methods=['GET'])
@login_required
def get_task_status(task_arn):
    """Get status of a running ECS task"""
    try:
        status = task_runner.get_task_status(task_arn)
        return jsonify(status)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/task/<path:task_arn>/stop', methods=['POST'])
@login_required
def stop_task(task_arn):
    """Stop a running ECS task"""
    try:
        result = task_runner.stop_task(task_arn, reason='Stopped by user')
        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    for d in ['scripts', 'templates', 'static/js', 'static/css']:
        os.makedirs(d, exist_ok=True)

    print(f"\nAutomation UI running on http://localhost:5000")
    print(f"DB: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
    print(f"Login: admin/admin123 or user/password\n")

    app.run(debug=True, host='0.0.0.0', port=5000)

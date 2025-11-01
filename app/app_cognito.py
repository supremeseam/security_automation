"""
Flask Application with AWS Cognito Authentication

This version replaces database-based authentication with AWS Cognito OAuth2.
"""

from flask import Flask, render_template, request, jsonify, redirect, url_for, flash, session
from flask_cors import CORS
import mysql.connector
import json
import subprocess
import os
import sys
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv
from cognito_auth import CognitoAuth, get_current_user, create_user_from_cognito

load_dotenv()

app = Flask(__name__, static_folder='static', template_folder='templates')
app.secret_key = os.getenv('SECRET_KEY', 'dev-secret-key-change-in-production')
CORS(app)

# Initialize Cognito Authentication
cognito = CognitoAuth(app)

# Database configuration (still used for logging automation runs)
DB_CONFIG = {
    'host': os.getenv('DB_HOST', '10.20.72.84'),
    'port': int(os.getenv('DB_PORT', 3306)),
    'database': os.getenv('DB_NAME', 'automation_ui'),
    'user': os.getenv('DB_USER', 'root'),
    'password': os.getenv('DB_PASSWORD', '')
}

def get_db():
    """Get database connection"""
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Exception as e:
        print(f"DB connection failed: {e}")
        return None

def load_config():
    """Load automation configuration"""
    with open(Path(__file__).parent / 'config' / 'automations_config.json') as f:
        return json.load(f)

def log_run(user_id, auto_id, auto_name, params, success, output, exec_time):
    """Log automation execution to database"""
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

# ============================================
# Authentication Routes
# ============================================

@app.route('/login')
def login():
    """Redirect to Cognito Hosted UI for login"""
    if 'user' in session:
        return redirect(url_for('index'))

    login_url = cognito.get_login_url()
    return redirect(login_url)

@app.route('/callback')
def callback():
    """Handle OAuth2 callback from Cognito"""
    code = request.args.get('code')
    error = request.args.get('error')

    if error:
        flash(f'Authentication error: {error}', 'error')
        return redirect(url_for('login'))

    if not code:
        flash('No authorization code received', 'error')
        return redirect(url_for('login'))

    try:
        # Exchange code for tokens
        tokens = cognito.exchange_code_for_tokens(code)

        # Verify and decode ID token
        id_token = tokens.get('id_token')
        access_token = tokens.get('access_token')
        refresh_token = tokens.get('refresh_token')

        user_data = cognito.verify_token(id_token)

        if not user_data:
            flash('Token verification failed', 'error')
            return redirect(url_for('login'))

        # Create user session
        user = create_user_from_cognito(user_data)
        session['user'] = user
        session['id_token'] = id_token
        session['access_token'] = access_token
        session['refresh_token'] = refresh_token

        flash(f'Welcome, {user["full_name"] or user["username"]}!', 'success')
        return redirect(url_for('index'))

    except Exception as e:
        print(f"Callback error: {e}")
        flash(f'Authentication failed: {str(e)}', 'error')
        return redirect(url_for('login'))

@app.route('/logout')
def logout():
    """Logout user and clear session"""
    session.clear()
    flash('Logged out successfully', 'success')

    # Redirect to Cognito logout
    logout_url = cognito.get_logout_url()
    return redirect(logout_url)

# ============================================
# Application Routes
# ============================================

@app.route('/')
@cognito.login_required
def index():
    """Main application page"""
    user = get_current_user()
    return render_template('index.html', user=user)

@app.route('/api/automations')
@cognito.login_required
def get_automations():
    """Get list of available automations"""
    try:
        return jsonify(load_config()['automations'])
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/run', methods=['POST'])
@cognito.login_required
def run_automation():
    """Execute an automation script"""
    start = datetime.now()
    user = get_current_user()

    try:
        data = request.json
        auto_id = data.get('automation_id')
        params = data.get('parameters', {})

        config = load_config()
        automation = next((a for a in config['automations'] if a['id'] == auto_id), None)

        if not automation:
            return jsonify({'error': 'Automation not found'}), 404

        script = Path(__file__).parent / automation['script']
        if not script.exists():
            return jsonify({'error': f'Script not found'}), 404

        cmd = [sys.executable, str(script)]

        # Build command with parameters
        for param in automation['parameters']:
            val = params.get(param['name'])
            if val is not None:
                if param['type'] == 'checkbox':
                    if val:
                        cmd.append(f'--{param["name"]}')
                else:
                    cmd.extend([f'--{param["name"]}', str(val)])

        # Execute script
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        exec_time = (datetime.now() - start).total_seconds()

        # Log execution
        log_run(user['id'], auto_id, automation['name'], params,
                result.returncode == 0, result.stdout or result.stderr, exec_time)

        return jsonify({
            'success': result.returncode == 0,
            'returncode': result.returncode,
            'stdout': result.stdout,
            'stderr': result.stderr
        })

    except subprocess.TimeoutExpired:
        exec_time = (datetime.now() - start).total_seconds()
        log_run(user['id'], auto_id, automation.get('name', 'Unknown'),
                params, False, 'Timeout', exec_time)
        return jsonify({'error': 'Script timed out (5 min)'}), 408
    except Exception as e:
        exec_time = (datetime.now() - start).total_seconds()
        log_run(user['id'], auto_id if 'auto_id' in locals() else 'unknown',
                'Unknown', params if 'params' in locals() else {}, False, str(e), exec_time)
        return jsonify({'error': str(e)}), 500

@app.route('/api/user')
@cognito.login_required
def get_user():
    """Get current user information"""
    user = get_current_user()
    return jsonify(user)

# ============================================
# Health Check Routes
# ============================================

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'auth_method': 'cognito'
    })

# ============================================
# Initialization
# ============================================

# Create necessary directories on startup
for d in ['scripts', 'templates', 'static/js', 'static/css', 'log']:
    os.makedirs(d, exist_ok=True)

if __name__ == '__main__':
    # Development mode
    print(f"\nAutomation UI running on http://localhost:5000")
    print(f"Authentication: AWS Cognito")
    print(f"DB: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}\n")
    print(f"Cognito User Pool: {os.getenv('COGNITO_USER_POOL_ID')}")
    print(f"App Domain: {os.getenv('APP_DOMAIN')}\n")

    app.run(debug=True, host='0.0.0.0', port=5000)
else:
    # Production mode
    print(f"Production mode: Cognito Auth | DB={DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")

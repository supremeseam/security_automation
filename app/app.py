from flask import Flask, render_template, request, jsonify, redirect, url_for, g
from flask_cors import CORS
import json
import os
from pathlib import Path
from datetime import datetime
from dotenv import load_dotenv
from functools import wraps
import requests
from jose import jwt
import mysql.connector

from task_runner import get_task_runner

load_dotenv()

# --- Cognito Configuration ---
COGNITO_DOMAIN = os.getenv('COGNITO_DOMAIN')
COGNITO_USER_POOL_ID = os.getenv('COGNITO_USER_POOL_ID')
COGNITO_APP_CLIENT_ID = os.getenv('COGNITO_APP_CLIENT_ID')
COGNITO_REGION = os.getenv('AWS_REGION', 'us-east-1')

COGNITO_BASE_URL = f"https://{COGNITO_DOMAIN}.auth.{COGNITO_REGION}.amazoncognito.com"
COGNITO_TOKEN_URL = f"{COGNITO_BASE_URL}/oauth2/token"
COGNITO_JKS_URL = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"

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

def get_db():
    try:
        return mysql.connector.connect(**DB_CONFIG)
    except Exception as e:
        print(f"DB connection failed: {e}")
        return None

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

# --- Security: JWT Validation ---
# Fetch the JSON Web Key Set (JWKS) from Cognito
# This is used to verify the signature of the JWTs.
response = requests.get(COGNITO_JKS_URL)
JKS = response.json()["keys"]

def cognito_login_required(f):
    """
    A decorator to protect routes with Cognito JWT validation.
    It expects a JWT in the 'Authorization: Bearer <token>' header.
    If the token is valid, the user's claims are stored in g.user.
    """
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({"error": "Authorization header is missing or invalid"}), 401

        token = auth_header.split(' ')[1]

        try:
            # Find the key in the JWKS that matches the key ID in the token header
            unverified_header = jwt.get_unverified_header(token)
            rsa_key = {}
            for key in JKS:
                if key["kid"] == unverified_header["kid"]:
                    rsa_key = {
                        "kty": key["kty"],
                        "kid": key["kid"],
                        "use": key["use"],
                        "n": key["n"],
                        "e": key["e"]
                    }
            if not rsa_key:
                return jsonify({"error": "Public key not found"}), 401

            # Verify the token
            payload = jwt.decode(
                token,
                rsa_key,
                algorithms=['RS256'],
                audience=COGNITO_APP_CLIENT_ID,
                issuer=f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}"
            )

            # Store the user claims in the request context for use in the route
            g.user = payload

        except jwt.ExpiredSignatureError:
            return jsonify({"error": "Token has expired"}), 401
        except jwt.JWTClaimsError:
            return jsonify({"error": "Invalid claims, please check the audience and issuer"}), 401
        except Exception as e:
            return jsonify({"error": f"Token validation error: {str(e)}"}), 401

        return f(*args, **kwargs)

    return decorated_function

# --- Authentication Routes ---

@app.route('/login')
def login():
    """
    Redirects to the Cognito Hosted UI for authentication.
    """
    redirect_uri = url_for('callback', _external=True)
    login_url = f"{COGNITO_BASE_URL}/login?response_type=code&client_id={COGNITO_APP_CLIENT_ID}&redirect_uri={redirect_uri}"
    return redirect(login_url)

@app.route('/logout')
def logout():
    """
    Redirects to the Cognito Hosted UI for logout.
    """
    redirect_uri = url_for('index', _external=True)
    logout_url = f"{COGNITO_BASE_URL}/logout?client_id={COGNITO_APP_CLIENT_ID}&logout_uri={redirect_uri}"
    return redirect(logout_url)

@app.route('/callback')
def callback():
    """
    Handles the callback from Cognito after a successful login.
    Exchanges the authorization code for tokens and returns them to the frontend.
    """
    code = request.args.get('code')
    if not code:
        return jsonify({"error": "Authorization code not found"}), 400

    redirect_uri = url_for('callback', _external=True)

    token_request_data = {
        'grant_type': 'authorization_code',
        'client_id': COGNITO_APP_CLIENT_ID,
        'code': code,
        'redirect_uri': redirect_uri
    }

    try:
        response = requests.post(COGNITO_TOKEN_URL, data=token_request_data)
        response.raise_for_status()
        tokens = response.json()

        # Security: The tokens are rendered in a simple HTML page.
        # The frontend JavaScript will be responsible for extracting these tokens
        # from the URL and storing them securely (e.g., in localStorage).
        return render_template('callback.html', tokens=tokens)

    except requests.exceptions.RequestException as e:
        return jsonify({"error": f"Failed to exchange code for tokens: {str(e)}"}), 500

# --- API Routes ---

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/api/automations')
@cognito_login_required
def get_automations():
    try:
        user_groups = g.user.get('cognito:groups', [])
        with open(Path(__file__).parent / 'config' / 'automations_config.json') as f:
            all_automations = json.load(f)['automations']
        
        authorized_automations = []
        for auto in all_automations:
            auth_groups = auto.get('authorized_groups')
            if auth_groups is None:
                authorized_automations.append(auto)
            elif any(group in user_groups for group in auth_groups):
                authorized_automations.append(auto)

        return jsonify(authorized_automations)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/run', methods=['POST'])
@cognito_login_required
def run_automation():
    """Run automation script in isolated container (ECS) or subprocess (local dev)"""
    start = datetime.now()
    try:
        data = request.json
        auto_id = data.get('automation_id')
        params = data.get('parameters', {})

        # Get user ID from the validated Cognito token
        user_id = g.user.get('sub')

        with open(Path(__file__).parent / 'config' / 'automations_config.json') as f:
            config = json.load(f)
        automation = next((a for a in config['automations'] if a['id'] == auto_id), None)

        if not automation:
            return jsonify({'error': 'Automation not found'}), 404

        # Authorization check
        auth_groups = automation.get('authorized_groups')
        user_groups = g.user.get('cognito:groups', [])
        if auth_groups is not None and not any(group in user_groups for group in auth_groups):
            return jsonify({'error': 'User not authorized to run this automation'}), 403

        result = task_runner.run_script(
            script_path=automation['script'],
            parameters=params,
            automation_id=auto_id,
            user_id=user_id
        )

        if not result.get('success'):
            # Task failed to launch
            exec_time = (datetime.now() - start).total_seconds()
            log_run(user_id, auto_id, automation['name'], params,
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
            log_run(user_id, auto_id, automation['name'], params,
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
        log_run(g.user.get('sub') if 'g' in locals() and hasattr(g, 'user') else 'unknown', auto_id if 'auto_id' in locals() else 'unknown',
                'Unknown', params if 'params' in locals() else {}, False, str(e), exec_time)
        return jsonify({'error': str(e)}), 500

@app.route('/api/task/<path:task_arn>/status', methods=['GET'])
@cognito_login_required
def get_task_status(task_arn):
    """Get status of a running ECS task"""
    try:
        status = task_runner.get_task_status(task_arn)
        return jsonify(status)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/task/<path:task_arn>/stop', methods=['POST'])
@cognito_login_required
def stop_task(task_arn):
    """Stop a running ECS task"""
    try:
        result = task_runner.stop_task(task_arn, reason='Stopped by user')
        return jsonify(result)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)


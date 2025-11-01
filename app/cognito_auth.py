"""
AWS Cognito Authentication Module for Flask

This module handles OAuth2 authentication flow with AWS Cognito.
"""

import os
import requests
import boto3
from jose import jwt, JWTError
from functools import wraps
from flask import session, redirect, url_for, request, jsonify
from datetime import datetime, timedelta
import json

class CognitoAuth:
    def __init__(self, app=None):
        self.app = app
        if app is not None:
            self.init_app(app)

    def init_app(self, app):
        """Initialize the Cognito authentication module"""
        self.user_pool_id = os.getenv('COGNITO_USER_POOL_ID')
        self.client_id = os.getenv('COGNITO_CLIENT_ID')
        self.cognito_domain = os.getenv('COGNITO_DOMAIN')
        self.region = os.getenv('COGNITO_REGION', 'us-east-1')
        self.app_domain = os.getenv('APP_DOMAIN', 'localhost:5000')

        # Construct URLs
        self.redirect_uri = f"https://{self.app_domain}/callback"
        self.logout_redirect_uri = f"https://{self.app_domain}"

        # Get JWKS URL for token verification
        self.jwks_url = f"https://cognito-idp.{self.region}.amazonaws.com/{self.user_pool_id}/.well-known/jwks.json"

        # Cache for JWKS
        self._jwks = None
        self._jwks_fetch_time = None

        # Store config in app
        app.config['COGNITO_USER_POOL_ID'] = self.user_pool_id
        app.config['COGNITO_CLIENT_ID'] = self.client_id
        app.config['COGNITO_DOMAIN'] = self.cognito_domain
        app.config['COGNITO_REGION'] = self.region

    def get_jwks(self):
        """Fetch JWKS (JSON Web Key Set) from Cognito"""
        # Cache JWKS for 1 hour
        if self._jwks and self._jwks_fetch_time:
            if datetime.now() - self._jwks_fetch_time < timedelta(hours=1):
                return self._jwks

        response = requests.get(self.jwks_url)
        response.raise_for_status()
        self._jwks = response.json()
        self._jwks_fetch_time = datetime.now()
        return self._jwks

    def get_login_url(self):
        """Generate Cognito Hosted UI login URL"""
        params = {
            'client_id': self.client_id,
            'response_type': 'code',
            'scope': 'email openid profile',
            'redirect_uri': self.redirect_uri
        }

        query_string = '&'.join([f"{k}={v}" for k, v in params.items()])
        return f"https://{self.cognito_domain}/login?{query_string}"

    def get_logout_url(self):
        """Generate Cognito Hosted UI logout URL"""
        params = {
            'client_id': self.client_id,
            'logout_uri': self.logout_redirect_uri
        }

        query_string = '&'.join([f"{k}={v}" for k, v in params.items()])
        return f"https://{self.cognito_domain}/logout?{query_string}"

    def exchange_code_for_tokens(self, code):
        """Exchange authorization code for tokens"""
        token_url = f"https://{self.cognito_domain}/oauth2/token"

        data = {
            'grant_type': 'authorization_code',
            'client_id': self.client_id,
            'code': code,
            'redirect_uri': self.redirect_uri
        }

        headers = {
            'Content-Type': 'application/x-www-form-urlencoded'
        }

        response = requests.post(token_url, data=data, headers=headers)
        response.raise_for_status()
        return response.json()

    def verify_token(self, token):
        """Verify and decode JWT token"""
        try:
            # Get JWKS
            jwks = self.get_jwks()

            # Get the kid from the token header
            headers = jwt.get_unverified_header(token)
            kid = headers['kid']

            # Find the correct key
            key = None
            for jwk_key in jwks['keys']:
                if jwk_key['kid'] == kid:
                    key = jwk_key
                    break

            if not key:
                raise JWTError('Public key not found in JWKS')

            # Verify and decode token
            decoded = jwt.decode(
                token,
                key,
                algorithms=['RS256'],
                audience=self.client_id,
                issuer=f"https://cognito-idp.{self.region}.amazonaws.com/{self.user_pool_id}"
            )

            return decoded

        except JWTError as e:
            print(f"Token verification failed: {e}")
            return None

    def get_user_info(self, access_token):
        """Get user information from Cognito"""
        userinfo_url = f"https://{self.cognito_domain}/oauth2/userInfo"

        headers = {
            'Authorization': f'Bearer {access_token}'
        }

        response = requests.get(userinfo_url, headers=headers)
        response.raise_for_status()
        return response.json()

    def login_required(self, f):
        """Decorator to protect routes with Cognito authentication"""
        @wraps(f)
        def decorated_function(*args, **kwargs):
            # Check if user is authenticated
            if 'user' not in session or 'id_token' not in session:
                # Redirect to login
                return redirect(url_for('login'))

            # Verify token is still valid
            id_token = session.get('id_token')
            user_data = self.verify_token(id_token)

            if not user_data:
                # Token expired or invalid, clear session and redirect to login
                session.clear()
                return redirect(url_for('login'))

            # Token is valid, proceed with request
            return f(*args, **kwargs)

        return decorated_function


def get_current_user():
    """Get current authenticated user from session"""
    return session.get('user')


def create_user_from_cognito(cognito_data):
    """Transform Cognito user data into application user format"""
    return {
        'id': cognito_data.get('sub'),
        'username': cognito_data.get('cognito:username') or cognito_data.get('preferred_username'),
        'email': cognito_data.get('email'),
        'full_name': cognito_data.get('name', ''),
        'email_verified': cognito_data.get('email_verified', False)
    }

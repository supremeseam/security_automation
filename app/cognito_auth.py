import os
import requests
import jwt
from jwt import PyJWKClient

class CognitoAuth:
    def __init__(self):
        self.region = os.getenv('AWS_REGION', 'us-east-1')
        self.user_pool_id = os.getenv('COGNITO_USER_POOL_ID')
        self.client_id = os.getenv('COGNITO_CLIENT_ID') 
        self.jwks_url = f'https://cognito-idp.{self.region}.amazonaws.com/{self.user_pool_id}/.well-known/jwks.json'
        self.domain = "py-auto-ui-auth-322c754a""
    def get_login_url(self, redirect_uri):
       
        return (
            f"https://{self.domain}.auth.{self.region}.amazoncognito.com/login"
            f"?response_type=code&client_id={self.client_id}&redirect_uri={redirect_uri}"
        )
    
    def exchange_code_for_tokens(self, code, redirect_uri):
        
        token_url = f"https://{self.domain}.auth.{self.region}.amazoncognito.com/oauth2/token"
        
        response = requests.post(token_url, data={
            'grant_type': 'authorization_code',
            'client_id': self.client_id,
            'code': code,
            'redirect_uri': redirect_uri
        })
        
        return response.json()  
    
    def verify_token(self, token):
        jwks_client = PyJWKClient(self.jwks_url)
        signing_key = jwks_client.get_signing_key_from_jwt(token)
        
        data = jwt.decode(
            token,
            signing_key.key,
            algorithms=["RS256"],
            audience=self.client_id,
            options={"verify_exp": True}
        )
        return data
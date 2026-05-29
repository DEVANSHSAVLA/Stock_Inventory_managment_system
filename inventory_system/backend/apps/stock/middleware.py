from channels.middleware import BaseMiddleware
from channels.db import database_sync_to_async
from django.contrib.auth.models import AnonymousUser
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from urllib.parse import parse_qs


@database_sync_to_async
def get_user_from_token(token_key, schema_name):
    from django.db import connection
    if schema_name:
        connection.set_schema(schema_name)
    from apps.auth_app.models import User
    try:
        token = AccessToken(token_key)
        user_id = token.get('user_id')
        return User.objects.get(pk=user_id)
    except (InvalidToken, TokenError, User.DoesNotExist):
        return AnonymousUser()


class JWTAuthMiddleware(BaseMiddleware):
    async def __call__(self, scope, receive, send):
        query_string = scope.get('query_string', b'').decode()
        params = parse_qs(query_string)
        token_list = params.get('token', [])
        schema_list = params.get('tenant', [])
        
        schema_name = schema_list[0] if schema_list else None
        
        if token_list:
            token_key = token_list[0]
            try:
                # Also try to extract tenant from token if not in query param
                token = AccessToken(token_key)
                if not schema_name and 'tenant_schema' in token:
                    schema_name = token['tenant_schema']
            except Exception:
                pass
            scope['tenant_schema'] = schema_name
            scope['user'] = await get_user_from_token(token_key, schema_name)
        else:
            scope['tenant_schema'] = schema_name
            scope['user'] = AnonymousUser()
        return await super().__call__(scope, receive, send)


def JWTAuthMiddlewareStack(inner):
    return JWTAuthMiddleware(inner)

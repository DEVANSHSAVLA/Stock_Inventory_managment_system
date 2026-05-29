from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from .serializers import LoginSerializer, UserSerializer, UserCreateSerializer
from .models import User
from apps.audit.utils import log_audit


def success_response(data=None, message='', status_code=status.HTTP_200_OK):
    return Response({'success': True, 'data': data or {}, 'message': message, 'errors': {}}, status=status_code)


def error_response(errors=None, message='', status_code=status.HTTP_400_BAD_REQUEST):
    return Response({'success': False, 'data': {}, 'message': message, 'errors': errors or {}}, status=status_code)


@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    subdomain = request.data.get('subdomain', 'demo')
    if subdomain:
        try:
            from apps.tenants.models import Tenant
            from django.db import connection
            tenant = Tenant.objects.get(subdomain=subdomain)
            connection.set_tenant(tenant)
        except Tenant.DoesNotExist:
            return error_response(message=f"Workspace '{subdomain}' not found.", status_code=status.HTTP_400_BAD_REQUEST)
            
    serializer = LoginSerializer(data=request.data)
    if not serializer.is_valid():
        return error_response(errors=serializer.errors, message='Login failed.')
    user = serializer.validated_data['user']
    refresh = RefreshToken.for_user(user)
    
    # Inject the tenant schema name as a custom claim
    from django.db import connection
    if hasattr(connection, 'tenant') and connection.tenant:
        refresh['tenant_schema'] = connection.tenant.schema_name
        
    return success_response(data={
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'user': UserSerializer(user).data,
    }, message='Login successful.')


@api_view(['POST'])
@permission_classes([AllowAny])
def refresh_view(request):
    from rest_framework_simplejwt.views import TokenRefreshView
    from .serializers import CustomTokenRefreshSerializer
    
    class CustomTokenRefreshView(TokenRefreshView):
        serializer_class = CustomTokenRefreshSerializer
        
    view = CustomTokenRefreshView.as_view()
    return view(request._request)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout_view(request):
    try:
        refresh_token = request.data.get('refresh')
        if refresh_token:
            token = RefreshToken(refresh_token)
            token.blacklist()
    except Exception:
        pass
    return success_response(message='Logged out successfully.')


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def me_view(request):
    from django.db import connection
    from apps.tenants.serializers import TenantDetailSerializer
    
    tenant_data = None
    if hasattr(connection, 'tenant'):
        tenant_data = TenantDetailSerializer(connection.tenant).data
        
    return success_response(data={
        'user': UserSerializer(request.user).data,
        'tenant': tenant_data
    })


from rest_framework import generics
from rest_framework.views import APIView


class UserListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if not request.user.is_admin:
            return error_response(message='Admin access required.', status_code=status.HTTP_403_FORBIDDEN)
        users = User.objects.all().order_by('-created_at')
        serializer = UserSerializer(users, many=True)
        return success_response(data={'results': serializer.data, 'count': users.count()})

    def post(self, request):
        if not request.user.is_admin:
            return error_response(message='Admin access required.', status_code=status.HTTP_403_FORBIDDEN)
        serializer = UserCreateSerializer(data=request.data)
        if not serializer.is_valid():
            return error_response(errors=serializer.errors, message='Validation failed.')
        user = serializer.save()
        log_audit(request, 'CREATE', 'User', user.pk, None, UserSerializer(user).data)
        return success_response(data=UserSerializer(user).data, message='User created.', status_code=status.HTTP_201_CREATED)


class UserDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk):
        try:
            return User.objects.get(pk=pk)
        except User.DoesNotExist:
            return None

    def get(self, request, pk):
        if not request.user.is_admin and request.user.pk != pk:
            return error_response(message='Access denied.', status_code=status.HTTP_403_FORBIDDEN)
        user = self.get_object(pk)
        if not user:
            return error_response(message='User not found.', status_code=status.HTTP_404_NOT_FOUND)
        return success_response(data=UserSerializer(user).data)

    def put(self, request, pk):
        if not request.user.is_admin and request.user.pk != pk:
            return error_response(message='Access denied.', status_code=status.HTTP_403_FORBIDDEN)
        user = self.get_object(pk)
        if not user:
            return error_response(message='User not found.', status_code=status.HTTP_404_NOT_FOUND)
        old_data = UserSerializer(user).data
        serializer = UserSerializer(user, data=request.data, partial=True)
        if not serializer.is_valid():
            return error_response(errors=serializer.errors)
        user = serializer.save()
        log_audit(request, 'UPDATE', 'User', user.pk, old_data, UserSerializer(user).data)
        return success_response(data=UserSerializer(user).data, message='User updated.')

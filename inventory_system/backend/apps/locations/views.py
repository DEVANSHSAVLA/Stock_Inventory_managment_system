from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from rest_framework.response import Response
from .models import Location
from .serializers import LocationSerializer
from apps.audit.utils import log_audit


def ok(data=None, msg='', code=status.HTTP_200_OK):
    return Response({'success': True, 'data': data or {}, 'message': msg, 'errors': {}}, status=code)

def err(errors=None, msg='', code=status.HTTP_400_BAD_REQUEST):
    return Response({'success': False, 'data': {}, 'message': msg, 'errors': errors or {}}, status=code)


class LocationListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Location.objects.filter(is_active=True).order_by('name')
        return ok(data={'results': LocationSerializer(qs, many=True).data, 'count': qs.count()})

    def post(self, request):
        if not (request.user.is_admin or request.user.is_manager):
            return err(msg='Permission denied.', code=status.HTTP_403_FORBIDDEN)
        s = LocationSerializer(data=request.data)
        if not s.is_valid():
            return err(errors=s.errors)
        loc = s.save()
        log_audit(request, 'CREATE', 'Location', loc.pk, None, s.data)
        return ok(data=s.data, msg='Location created.', code=status.HTTP_201_CREATED)

from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework import status
from rest_framework.response import Response
from .models import Notification
from .serializers import NotificationSerializer


def ok(data=None, msg='', code=status.HTTP_200_OK):
    return Response({'success': True, 'data': data or {}, 'message': msg, 'errors': {}}, status=code)

def err(errors=None, msg='', code=status.HTTP_400_BAD_REQUEST):
    return Response({'success': False, 'data': {}, 'message': msg, 'errors': errors or {}}, status=code)


class NotificationListView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Notification.objects.filter(user=request.user).order_by('-created_at')
        unread_count = qs.filter(is_read=False).count()
        return ok(data={
            'results': NotificationSerializer(qs[:50], many=True).data,
            'unread_count': unread_count,
        })


class NotificationReadView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            n = Notification.objects.get(pk=pk, user=request.user)
        except Notification.DoesNotExist:
            return err(msg='Not found.', code=status.HTTP_404_NOT_FOUND)
        n.is_read = True
        n.save()
        return ok(msg='Marked as read.')


class NotificationReadAllView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request):
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return ok(msg='All notifications marked as read.')

import json
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async


class StockConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope.get('user')
        self.schema_name = self.scope.get('tenant_schema')
        
        if not self.user or not self.user.is_authenticated or not self.schema_name:
            await self.close()
            return
            
        self.group_name = f"{self.schema_name}_stock_updates"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        await self.send(text_data=json.dumps({
            'type': 'connection_established',
            'message': f'Connected to {self.schema_name} stock updates',
        }))

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        pass

    async def stock_update(self, event):
        await self.send(text_data=json.dumps(event['payload']))

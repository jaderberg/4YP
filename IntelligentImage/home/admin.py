from django.contrib import admin
from home.models import UploadedImage


admin.site.register(UploadedImage, admin.ModelAdmin)
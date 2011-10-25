from django import forms
from home.models import UploadedImage

class UploadedImageForm(forms.ModelForm):

    class Meta:
        model = UploadedImage
        fields = ('image',)
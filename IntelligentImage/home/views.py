from django.template.response import TemplateResponse
from home.forms import UploadedImageForm

def home(request):

    image_form = UploadedImageForm()

    return TemplateResponse(request, 'home.html', {'form': image_form})


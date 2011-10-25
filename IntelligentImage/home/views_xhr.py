from django.http import HttpResponseRedirect
from home.decorators import json_response
from django.core.urlresolvers import reverse
from home.forms import UploadedImageForm

@json_response
def upload_image(request):

    if not request.method == 'POST':
        return HttpResponseRedirect(reverse('home'))

    response = {
        'success': False
    }


    image_form = UploadedImageForm(request.POST, request.FILES)

    if image_form.is_valid():
        image = image_form.save(commit=False)
        # TODO: Hash files to avoid duplicates
        image.save()
        response['success'] = True
        response['url'] = image.image.url
    else:
        response['errors'] = image_form.errors

    return response

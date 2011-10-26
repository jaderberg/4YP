from django.http import HttpResponseRedirect
from django.template.context import RequestContext
from django.template.loader import render_to_string
from home.decorators import json_response
from django.core.urlresolvers import reverse
from home.forms import UploadedImageForm
from home.models import UploadedImage
import time

@json_response
def upload_image(request):

    if not request.method == 'POST':
        return HttpResponseRedirect(reverse('home'))

    response = {
        'success': False
    }

    ########### TAKE THIS OUT IN PRODUCTION!!!!
    time.sleep(1)
    ###################################
    image_form = UploadedImageForm(request.POST, request.FILES)

    if image_form.is_valid():
        image = image_form.save(commit=False)
        # TODO: Hash files to avoid duplicates
        image.save()
        response['success'] = True
        response['url'] = image.image.url
        response['html'] = render_to_string('untagged_image.html', {'image': image}, context_instance=RequestContext(request))
    else:
        response['error'] = image_form.errors

    return response

@json_response
def tag_image(request, image_id):

    if not request.method == 'POST':
        return HttpResponseRedirect(reverse('home'))

    response = {
        'success': False
    }

    try:
        uploaded_image = UploadedImage.objects.get(id=image_id)
    except UploadedImage.DoesNotExist:
        response['error'] = 'Image does not exist'
        return response

    # List of recognised objects
    objects = []

    image_file = uploaded_image.image.file
    # DO SOMETHING WITH THE IMAGE
    ########### TAKE THIS OUT IN PRODUCTION!!!!
    time.sleep(2)
    ###################################
    objects.append({
        'label': 'Buckingham Palace',
        'url': 'http://en.wikipedia.org/wiki/Buckingham_Palace',
        'left': 200,
        'top': 120,
        'width': 300,
        'height': 100,
    })
    objects.append({
        'label': 'Victoria Memorial',
        'url': 'http://en.wikipedia.org/wiki/Victoria_Memorial_(London)',
        'left': 50,
        'top': 50,
        'width': 80,
        'height': 100,
    })

    response['success'] = True
    response['html'] = render_to_string('tagged_image.html', {'image': uploaded_image, 'objects': objects}, context_instance=RequestContext(request))

    return response
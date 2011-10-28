from django.db import models

class UploadedImage(models.Model):
    created = models.DateTimeField(auto_now_add=True)
    image = models.ImageField(upload_to='uploads/')

    def __unicode__(self):
        return unicode(self.image)
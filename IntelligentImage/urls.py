from django.conf.urls.defaults import patterns, include, url
from django.conf import settings

# Uncomment the next two lines to enable the admin:
from django.contrib import admin
admin.autodiscover()

urlpatterns = patterns('',
    # Examples:
    # url(r'^$', 'IntelligentImage.views.home', name='home'),
    # url(r'^IntelligentImage/', include('IntelligentImage.foo.urls')),

    # Uncomment the admin/doc line below to enable admin documentation:
    # url(r'^admin/doc/', include('django.contrib.admindocs.urls')),

    # Uncomment the next line to enable the admin:
    url(r'^$', 'IntelligentImage.home.views.home', name='home'),
    url(r'^admin/', include(admin.site.urls)),
    url(r'^upload/$', 'IntelligentImage.home.views_xhr.upload_image', name='upload_image'),
    url(r'^session/$', 'IntelligentImage.home.views_xhr.get_session_key', name='get_session_key'),
    url(r'^log/$', 'IntelligentImage.home.views_xhr.get_log', name='get_log'),
    url(r'^log/cleanup/$', 'IntelligentImage.home.views_xhr.log_cleanup', name='log_cleanup'),
    url(r'^tag/(?P<image_id>[0-9]+)/$', 'IntelligentImage.home.views_xhr.tag_image', name='tag_image'),

)

# Serve media root
urlpatterns += patterns('',
        url(r'^media/(?P<path>.*)$', 'django.views.static.serve', {
            'document_root': settings.MEDIA_ROOT,
        }),
   )

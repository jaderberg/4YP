import os
import mwclient

PROJECT_ROOT = os.path.realpath( os.path.join(os.path.dirname(__file__), '../../'))

IMAGE_FOLDER = '%s/4yp_images/test_images' % PROJECT_ROOT
PAGE_NAME = 'List_of_tallest_buildings_in_the_world'

if not os.path.exists(IMAGE_FOLDER):
    os.makedirs(IMAGE_FOLDER)
    print 'Created %s' % IMAGE_FOLDER

site = mwclient.Site('en.wikipedia.org')
site.login('maxjaderberg', 'pascal28')

def download_images(page):
    """
    Downloads all the images on a Page object (e.g site.Pages['Albert_Einstein'])
    """
    page_url = 'http://en.wikipedia.org/wiki/%s' % page.normalize_title(page.page_title)

    print 'Downloading images from %s...' % page_url

    # iterates through the image objects and saves them
    counter = 0
    for image in page.images():
        fr = image.download()
        filename = '%s/%s|%s' % (IMAGE_FOLDER, page.normalize_title(page.page_title), page.normalize_title(image.page_title))
        try:
            fw = open(filename)
        except IOError:
            fw = open(filename, 'wrb')
            while True:
                s = fr.read(4096)
                if not s: break
                fw.write(s)
        fr.close() # Always close those file objects !!!
        fw.close()
        counter += 1
        print 'Downloaded: %s' % image.page_title

    return counter


# get a page - this should be a list page
buildings = site.Pages[PAGE_NAME]

counter = 0

for link in buildings.links():
    if link.page_title.find('List of ') == 0:
        # its a link to a list, so dont download
        print 'Link to a list - not downloading images'
        continue
    counter += download_images(link)

print ''
print 'Success! Downloaded %d images to %s' % (counter, IMAGE_FOLDER)
print ''



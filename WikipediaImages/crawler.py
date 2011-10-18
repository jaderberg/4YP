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

def download_images(page, no_flags=False):
    """
    Downloads all the images on a Page object (e.g site.Pages['Albert_Einstein'])
    """
    page_url = 'http://en.wikipedia.org/wiki/%s' % page.normalize_title(page.page_title)

    print '------------------------------------------------------------------'
    print 'Downloading images from %s...' % page_url

    # iterates through the image objects and saves them
    counter = 0
    for image in page.images():

        # Skip commons logo
        if image.page_title.find('Commons-logo') == 0:
            continue

        # Skip flags
        if image.page_title.find('Flag of ') == 0 and no_flags:
            continue

        fr = image.download()
        filename = '%s/%s|%s' % (IMAGE_FOLDER, page.normalize_title(page.page_title), page.normalize_title(image.page_title))
        # Avoid downloading duplicates
        duplicate = False
        try:
            fw = open(filename)
            duplicate = True
        except IOError:
            fw = open(filename, 'wrb')
            while True:
                s = fr.read(4096)
                if not s: break
                fw.write(s)
        fr.close() # Always close those file objects !!!
        fw.close()
        counter += 1
        print 'Downloaded: %s' % filename if not duplicate else 'Already downloaded: %s' % filename

    return counter


# get a page - this should be a list page
buildings = site.Pages[PAGE_NAME]

counter = 0

for link in buildings.links():
    if link.page_title.find('List of ') == 0:
        # its a link to a list, so dont download
        print 'Link to a list (%s) - not downloading images' % link.page_title
        continue
    counter += download_images(link, no_flags=True)

print ''
print 'Success! Downloaded %d images to %s' % (counter, IMAGE_FOLDER)
print ''



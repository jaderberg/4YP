import urllib2
from BeautifulSoup import BeautifulSoup
from urlparse import urljoin
import csv
import os

class WikiUrlReader(object):
    user_agent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.7) Gecko/2007091417 Firefox/2.0.0.7"

    def read(self, url, fail_silently=True):
        try:
            headers = {'User-Agent': self.user_agent}
            req = urllib2.Request(url, headers=headers)
            c=urllib2.urlopen(req)
        except urllib2.HTTPError, e:
            if fail_silently:
                print "Could not open %s" % url
                print e
                return None
            else:
                raise urllib2.HTTPError, e
        return c.read()

    def read_to_file(self, url, file, fail_silently=True):
        try:
            os.remove(file)
        except OSError:
            # file does not exist
            pass
        f = open(file, 'wb')
        f.write(self.read(url, fail_silently=fail_silently))
        f.close()
        return file


class Crawler(object):
    num_images = 0
    crawled_urls = {}
    image_file_urls_csv = None
    image_file_urls_csv_filename = None

    def crawl(self, pages, depth=2, csv_filename="image_file_urls.csv"):
        try:
            os.remove(csv_filename)
        except OSError:
            # file does not exist
            pass
        print "Saving image links to %s" % csv_filename
        self.image_file_urls_csv_filename = csv_filename
        self.image_file_urls_csv = csv.writer(open(csv_filename, "wb"))
        url_reader = WikiUrlReader()
        for i in range(depth):
            newpages = set()
            for page in pages:
                print 'Scraping %s' % page
                try:
                    soup = BeautifulSoup(url_reader.read(page))
                except TypeError:
                    continue
                soup = self._get_content_body(soup)
                if soup is None:
                    continue
                # Save the image links to the csv
                page_title =self._get_page_class(page)
                image_links = self._get_image_links(soup)
                for link in image_links:
                    if 'href' in dict(link.attrs):
                        self.image_file_urls_csv.writerow([page_title, urljoin(page, link['href'])])
                        self.num_images += 1

                links=soup('a')
                for link in links:
                    if 'href' in dict(link.attrs):
                        if link['href'][0] == '#':
                            continue
                        url=urljoin(page, link['href'])
                        if url.find("'") != -1:
                            continue
                        url = url.split('#')[0]
                        if url[0:4] == 'http':
                            newpages.add(url)
            pages = newpages
            self.crawled_urls[i] = newpages
        print '%d images crawled!' % self.num_images
        
    def _get_content_body(self, soup):
        main_content = soup.find('div', {"class": "mw-content-ltr"})
        if main_content is None:
            return None
        # remove navboxes
        navboxes = main_content.findAll('table', {'class': 'navbox'})
        [navbox.extract() for navbox in navboxes]
        return main_content

    def _get_image_links(self, soup):
        return soup.findAll('a', {'class': 'image'})

    def _get_page_class(self, page):
        return urllib2.unquote(page.split('/')[-1])

class WikipediaImageExtractor(object):

    def __init__(self, csv_filename, out_dir, image_formats=None, max_image_dimension=None):
        self.csv_filename = csv_filename
        self.out_dir = out_dir
        self.image_formats = image_formats
        self.images_extracted = 0
        self.max_image_dimension = max_image_dimension

    def download_images(self):
        # Create output dir
        if not os.path.exists(self.out_dir):
            os.makedirs(self.out_dir)
            print 'Created %s' % self.out_dir
        url_reader = WikiUrlReader()
        c = csv.reader(open(self.csv_filename, 'rb'))
        for i, row in enumerate(c):
            print 'Extracting image %d...' % i
            if len(row) != 2:
                print 'Invalid row format - skipping'
                continue
            class_name = urllib2.unquote(row[0])
            image_file_url = row[1]
            # check format of image
            image_format = image_file_url.split('.')[-1]
            is_image = False
            if self.image_formats is not None:
                if self.image_formats.count(image_format):
                    is_image = True
            else:
                is_image = True
            if not is_image:
                print 'Image format not allowed %s - skipping' % image_format
                continue

            # go to file page
            try:
                soup = BeautifulSoup(url_reader.read(image_file_url))
            except Exception:
                print 'Something went wrong - skipping'
                continue
            full_media = soup.find('div', {"class": "fullMedia"})
            file_info = full_media.find('span', {'class': 'fileInfo'})
            # get original resolution
            info_string = file_info.string.replace('(', '').replace(')', '')
            info_words = info_string.replace(',', '').split(' ')
            full_width = float(info_words[0])
            full_height = float(info_words[2])
            aspect = float(float(full_width)/float(full_height))
            # get original url
            image_link = full_media.find('a')
            original_image_url = 'http:%s' % image_link['href']
            image_filename = image_link['title']
            # check resolution
            print 'Image has resolution %s x %s' % (int(full_width), int(full_height))
            if self.max_image_dimension is None:
                # no restriction on resolution
                image_download_url = original_image_url
            else:
                # download the appropriate size
                if max(full_width, full_height) > self.max_image_dimension:
                    if full_width > full_height:
                        thumb_width = self.max_image_dimension
                    else:
                        thumb_width = int(aspect*self.max_image_dimension)
                    image_download_url = '%s/%spx-%s' % (original_image_url.replace('/commons/', '/commons/thumb/') if original_image_url.count('/commons/') else original_image_url.replace('/en/', '/en/thumb/'), thumb_width, original_image_url.split('/')[-1])
                else:
                    # original image is smaller than max resolution
                    image_download_url = original_image_url

            # make class dir
            class_dir = '%s/%s' % (self.out_dir, class_name)
            if not os.path.exists(class_dir):
                os.makedirs(class_dir)
                print 'Created %s' % class_dir

            # download the image
            out_filename = '%s/%s|%s.%s' % (class_dir, str(i), class_name, image_format.lower())
            try:
                print 'Downloading from %s to %s' % (image_download_url, out_filename)
            except UnicodeDecodeError:
                print 'Downloading to %s' % out_filename
            try:
                url_reader.read_to_file(image_download_url, out_filename)
            except Exception:
                continue
            self.images_extracted += 1
        print '-------------------------------------'
        print 'DOWNLOADED %d IMAGES' % self.images_extracted
        print '-------------------------------------'

#crawler = Crawler()
#crawler.crawl(['http://en.wikipedia.org/wiki/List_of_structures_in_London'], depth=2, csv_filename='/Volumes/4YP/Images/List_of_structures_in_London2.csv')
extractor = WikipediaImageExtractor('/Volumes/4YP/Images/List_of_structures_in_London2.csv', '/Volumes/4YP/Images/List_of_structures_in_London2', ['jpeg','jpg','JPG','JPEG'], 1000)
extractor.download_images()
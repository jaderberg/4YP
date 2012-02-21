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
    user_agent = "Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en-US; rv:1.8.1.7) Gecko/2007091417 Firefox/2.0.0.7"

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
                soup = BeautifulSoup(url_reader.read(page))
                soup = self._get_content_body(soup)
                if soup is None:
                    continue
                # Save the image links to the csv
                page_title =self._get_page_class(page)
                image_links = self._get_image_links(soup)
                for link in image_links:
                    if 'href' in dict(link.attrs):
                        self.image_file_urls_csv.writerow([page_title, urljoin(page, link['href'])])

                links=soup('a')
                for link in links:
                    if('href' in dict(link.attrs)):
                        url=urljoin(page, link['href'])
                        if url.find("'") != -1:
                            continue
                        url = url.split('#')[0]
                        if url[0:4] == 'http':
                            newpages.add(url)
            pages = newpages
            self.crawled_urls[i] = newpages
        print 'All done!'
    def _get_content_body(self, soup):
        return soup.find('div', {"class": "mw-content-ltr"})

    def _get_image_links(self, soup):
        return soup.findAll('a', {'class': 'image'})

    def _get_page_class(self, page):
        return page.split('/')[-1]

class WikipediaImageExtractor(object):

    def __init__(self, csv_file, out_dir, image_formats=None, max_image_dimension=None):
        self.csv_file = csv_file
        self.out_dir = out_dir
        self.image_formats = image_formats
        self.images_extracted = 0
        self.max_image_dimension = max_image_dimension

    def download_images(self):
        # Create output dir
        if not os.path.exists(out_dir):
            os.makedirs(out_dir)
            print 'Created %s' % out_dir
        url_reader = WikiUrlReader()
        c = csv.reader(open(csv_file, 'rb'))
        for row in c:
            if len(row) != 2:
                continue
            class_name = row[0]
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
                continue

            # go to file page
            soup = BeautifulSoup(url_reader.read(image_file_url))
            file_box = soup.find('div', {"id": "file"})
            full_media = soup.find('div', {"class": "fullMedia"})
            file_info = full_media.find('span', {'class': 'fileInfo'})
            # get original resolution
            info_string = str(file_info.span.string).replace('(', '')
            info_words = info_string.split(' ')
            full_width = info_words[0]
            full_height = info_words[2]
            aspect = float(float(full_width)/float(full_height))
            # get original url
            image_link = full_media.find('a')
            original_image_url = 'http:%s' % image_link['href']
            # check resolution
            if self.max_image_dimension is None:
                # no other sizes, download full image
                image_download_url = original_image_url
            else:
                # download the appropriate size
                pass


crawler = Crawler()
crawler.crawl(['http://en.wikipedia.org/wiki/List_of_structures_in_London'], depth=2)
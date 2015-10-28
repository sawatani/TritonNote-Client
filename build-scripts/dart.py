#!/usr/bin/env python

import hashlib
import os
import re
import sys
import urllib.request

from config import Config
import lxml.html
import yaml

config = Config()

def write_settings():
    target = os.path.join('dart', 'web', 'settings.yaml')
    def loadYaml():
        file = open(target, mode='r')
        try:
            return yaml.load(file)
        finally:
            file.close()
    def saveYaml(info):
        file = open(target, mode='w')
        try:
            yaml.dump(info, file, default_flow_style=False)
        finally:
            file.close()

    info = loadYaml()
    for (name, key) in info.items():
        info[name] = config.get(key)
    saveYaml(info)
    print('Set', target)

def download(url, dir):
    def getExt(base):
        m = re.search('.*[^\w]([\w]+)$', base.split('?')[0])
        if m == None:
            return None
        else:
            return m.group(1)
    def uniqueName(base):
        m = hashlib.md5()
        m.update(base.encode('utf-8'))
        return 'cached-%s.%s' % (m.hexdigest(), getExt(base))
    name = uniqueName(url)
    target = os.path.join(dir, name)
    print('Downloading', url, 'to', target)
    if not os.path.exists(dir):
        os.makedirs(dir)
    urllib.request.urlretrieve(url, target)
    return name

class IndexHtml:
    def __init__(self):
        self.index = os.path.join('dart', 'web', 'index.html')
        self.dom = self.loadIndex()

    def loadIndex(self):
        file = open(self.index, mode='r')
        try:
            return lxml.html.fromstring(file.read())
        finally:
            file.close()
    def saveIndex(self, dom):
        file = open(self.index, mode='w')
        try:
            dom.dump(file)
        finally:
            file.close()

    def fonts(self):
        dir = os.path.join('dart', 'web', 'styles', 'fonts')
        def modify(url):
            filename = download(url, dir)
            f = open(os.path.join(dir, filename), mode='r+')
            try:
                p = re.compile('(^.*url\()(https:[^\)]+)(\).*)')
                lines = f.readlines()
                f.seek(0)
                for line in lines:
                    m = p.match(line)
                    if m != None:
                        loaded = download(m.group(2), dir)
                        line = m.expand('\\1%s\\3' % loaded)
                    f.write(line)
                f.truncate()
                return filename
            finally:
                f.close()
        p = re.compile('^https://fonts.googleapis.com/css\?.*$')
        for css in self.dom.xpath("//link[@rel='stylesheet']"):
            href = css.attrib['href']
            if p.match(href):
                css.attrib['href'] = 'styles/fonts/' + modify(href)

    def js(self):
        print('Searching javascripts:', self.dom)

    def close(self):
        string = lxml.html.tostring(self.dom, include_meta_content_type=True)
        print('Writing', self.index)
        open(self.index, 'wb').write(string)

def all():
    write_settings()
    index = IndexHtml()
    index.fonts()
    index.js()
    index.close()

if __name__ == "__main__":
    action = sys.argv[1]
    if action == 'settings':
        write_settings()
    elif action == 'fonts':
        index = IndexHtml()
        index.fonts()
        index.close()
    elif action == 'js':
        index = IndexHtml()
        index.js()
        index.close()

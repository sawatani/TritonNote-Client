#!/usr/bin/env python

from glob import glob
import importlib
import os
import sys

import pip

from config import Config
import shell


def googleplay(track_name):
    print('Deploying to Google Play:', track_name)

    def install_import(package, module):
        pip.main(['install', package])
        globals()[module] = importlib.import_module(module)

    install_import('google-api-python-client', 'apiclient')

    keyp12 = Config.file('android', 'service_account_key.p12')
    for apk in glob('build', 'outputs', 'apk', '*-release.apk'):
        print(apk)

def crashlytics():
    print('Deploying to Crashlytics')
    shell.cmd('gradlew crashlyticsUploadDistributionRelease')

def all():
    dir = os.path.join('platforms', 'android')
    map = {
           'release': 'production',
           'beta': 'beta'
           }
    track_name = map.get(os.environ['BUILD_MODE'])

    here = os.getcwd()
    os.chdir(dir)
    try:
        if track_name:
            googleplay(track_name)
        else:
            crashlytics()
    finally:
        os.chdir(here)

if __name__ == "__main__":
    Config.load()

    action = sys.argv[1]
    if action == "googleplay":
        googleplay(sys.argv[2])
    elif action == "crashlytics":
        crashlytics()

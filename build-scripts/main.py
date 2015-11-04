#!/usr/bin/env python

import json
import os
import re
import sys

from config import Config
from github import GitHub
import android
import cordova_prepare
import dart
import ios
import shell


if __name__ == "__main__":
    print(sys.version)

    shell.on_root()
    Config.init()
    GitHub.init()

    note = GitHub.release_note()
    shell.marker_log('Release Note', note)
    target = Config.script_file('.release_note')
    with open(target, mode='w') as file:
        file.write(note + '\n')
    os.environ['RELEASE_NOTE_PATH'] = target

    dart.all()
    cordova_prepare.all()
    globals()[Config.PLATFORM].all()

    shell.marker_log('Tagging')
    tagged = GitHub.put_tag()
    print(json.dumps(tagged, indent=4))

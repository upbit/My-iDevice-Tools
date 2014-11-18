#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import re

def is_guid(dir_name):
	return re.match(r"[\da-fA-F]+-[\da-fA-F]+-[\da-fA-F]+-[\da-fA-F]+-[\da-fA-F]+", dir_name)

def is_apple_plist(file_name):
	return re.match(r"com.apple.[^.]+.plist", file_name)

def main():
	# iOS7: /var/mobile/Applications/<GUID>/Library/Preferences/<BundleId>.plist
	# iOS8: /var/mobile/Containers/Data/Application/<GUID>/Library/Preferences/<BundleId>.plist
	AppRoot = "/var/mobile/Applications/"
	if (not os.path.isdir(AppRoot)):
		AppRoot = "/var/mobile/Containers/Data/Application/"

	for d in os.listdir(AppRoot):
		if (os.path.isdir(AppRoot+d) and is_guid(d)):
			path = "%s%s/Library/Preferences/" % (AppRoot, d)
			for f in os.listdir(path):
				if (not is_apple_plist(f)):
					filename = "%s%s" % (path, f)
					print ">>> %s" % f
					os.system("plutil %s" % (filename))
					print " "


main()

# My iDevice Tools
###### A set of console tools for iOS devices, build with [Theos](http://iphonedevwiki.net/index.php/Theos/Setup).

Tools
----------
* **bundle_ids** - List bundle identifier for installed applications. (depend on **AppList**)
* **wifi_passwords** - Retrieve a saved WiFi password from keychain.

Compiling
----------
```shell
git clone https://github.com/upbit/My-iDevice-Tools.git
cd My-iDevice-Tools
ln -s /opt/theos ./
make
make ldid             # for ldid -Sent.xml
```

Requirements
----------

* [Theos](http://iphonedevwiki.net/index.php/Theos/Setup)
* [AppList](http://iphonedevwiki.net/index.php/AppList) on iOS

# My iDevice Tools
###### A set of console tools for iOS devices, build with [Theos](http://iphonedevwiki.net/index.php/Theos/Setup).

## Tools

### bundle_ids
List bundle identifier for installed applications. (depend on **AppList**)

~~~sh
# ./bundle_ids
com.apple.AppStore                              : App Store
com.apple.AskPermissionUI                       : AskPermissionUI
com.apple.datadetectors.DDActionsService        : DDActionsService
com.apple.DemoApp                               : DemoApp
com.apple.Diagnostics                           : Diagnostics
com.apple.FacebookAccountMigrationDialog        : FacebookAccountMigrationDialog
com.apple.facetime                              : FaceTime
...
~~~

### wifi_passwords
Retrieve a saved WiFi password from keychain. See more: [自己动手从iOS Keychain中恢复保存的Wifi密码](http://blog.imaou.com/theos/2014/11/12/retrieve_wifi_password_from_keychain.html)

~~~sh
# ./wifi_passwords
Magdalene: Retrieve Wifi password.
iPhone: 123456
~~~


### keychain_cat
Dump / modify and delete keychain v_Data. See more: [keychain_cat - 查看/修改keychain2数据的工具](http://blog.imaou.com/theos/2014/12/26/keychain_cat_tool.html)

~~~sh
# ./keychain_cat -d
>> keychain-access-groups:
6WX5RKLG95.com.supercell.reef
88L2Q4487U.com.tencent.mttlite
apple
com.apple.ProtectedCloudStorage
com.apple.PublicCloudStorage
com.apple.apsd
com.apple.assistant
com.apple.cloudd
com.apple.ind
com.apple.security.sos

# ./keychain_cat -g 6WX5RKLG95.com.supercell.reef -s com.supercell
<AccessGroup:6WX5RKLG95.com.supercell.reef, Service:com.supercell, Account:appRated>
{
  accc = "<SecAccessControlRef: 0x15563b70>";
  acct = appRated;
  agrp = "6WX5RKLG95.com.supercell.reef";
  cdat = "2014-11-11 23:33:33 +0000";
  class = genp;
  invi = 1;
  labl = Supercell;
  mdat = "2014-11-11 23:33:33 +0000";
  pdmn = ak;
  svce = "com.supercell";
  sync = 0;
  tomb = 0;
  "v_Data" = TRUE;
}
...

# ./keychain_cat -g 6WX5RKLG95.com.supercell.reef -s com.supercell -a THLevel -v 99 -U
Origin: {
  accc = "<SecAccessControlRef: 0x146798d0>";
  acct = THLevel;
  agrp = "6WX5RKLG95.com.supercell.reef";
  cdat = "2014-11-11 23:33:33 +0000";
  invi = 1;
  labl = Supercell;
  mdat = "2014-11-11 23:33:33 +0000";
  pdmn = ak;
  svce = "com.supercell";
  sync = 0;
  tomb = 0;
  "v_Data" = <3133>;
}
>> Update v_Data to: <3939>
~~~

---------

## Compiling

```shell
git clone https://github.com/upbit/My-iDevice-Tools.git
cd My-iDevice-Tools
ln -s /opt/theos ./
make
```

## Requirements

* [Theos](http://iphonedevwiki.net/index.php/Theos/Setup)
* [AppList](http://iphonedevwiki.net/index.php/AppList) on iOS (only **bundle_ids**)

#  HKSI Monitoring Station iOS

## Hacks

* GoogleWebRTC library (installed through CocoaPods) will not build unless `ENABLE_USER_SCRIPT_SANDBOXING` in Build Setting is turned off. Currently, I turned off this setting in the entire project.
* QN scale SDK are not built for iOS simulators. Thus, I set the "Supported Platforms" to be `iphoneos` only: that is, not `iOS` (which is ios real devices + simulators). 

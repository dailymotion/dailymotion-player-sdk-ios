###########################
Dailymotion Objective-C SDK
###########################

This repository contains the official open source Objective-C SDK that allows you to access the Dailymotion API from your Mac OS X or iOS application.

See documentation at http://www.dailymotion.com/doc/api/sdk-objc.html

NOTE: This is the version 2.0 of the Dailymotion SDK. This version raises the minimum iOS deployement version to 5.0. If you need iOS 3+ support, please see https://github.com/dailymotion/dailymotion-sdk-objc/tree/1.8.

Useful Resources
----------------

- Dailymotion SDK API Reference: http://dailymotion.github.com/dailymotion-sdk-objc/html/index.html
- Dailymotion API Reference: http://www.dailymotion.com/doc/api/reference.html
- Dailymotion API Explorer: http://www.dailymotion.com/doc/api/explorer

Installation
------------

Copy DailymotionSDK.framework in your project
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Download the last version of the framework from https://github.com/dailymotion/dailymotion-sdk-objc/downloads.
- Drag and drop the framework on your xcode project navigator and check the "Copy items into destination group's folder (if needed)" checkbox.

Add build target dependencies
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- In you application project app's target settings, find the "Build Phases" section and open the "Link Binary With Libraries" block.
- Click the "+" button again and select the ``Security.framework``
- Click the "+" button again and select the ``SystemConfiguration.framework``

Add Linker Flag
~~~~~~~~~~~~~~~

- Open the "Build Settings" tab, in the "Linking" section, locate the "Other Linker Flags" setting and add the "-ObjC" flag:

Import headers in your source files
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In the source files where you need to use the library, use #import ``<DailymotionSDK/DailymotionSDK.h>``::

    #import <DailymotionSDK/DailymotionSDK.h>


Feedback
--------

We are relying on the [GitHub issues tracker][issues] linked from above for feedback. File bugs or
other issues http://github.com/dailymotion/dailymotion-sdk-objc/issues

###########################
Dailymotion Objective-C SDK
###########################

This repository contains the official open source Objective-C SDK that allows you to access the Dailymotion API from your Mac OS X or iOS application.

See documentation at http://www.dailymotion.com/doc/api/sdk-objc.html

Installation
------------

Add the Dailymotion SDK project to your project
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- Right-click on the project navigator and select "Add Files to "Your Project"
- In the dialog, select ``Dailymotion SDK iOS.xcodeproj`` for iOS or ``Dailymotion SDK OSX.xcodeproj`` for OSX

After you’ve added the subproject, it’ll appear below the main project in Xcode’s Navigator tree.

Add build target dependencies
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

- In you application project app’s target settings, find the "Build Phases" section and open the "Target Dependencies" block.
- Click the "+" button and select ``Dailymotion SDK``
- Open the "Link Binary With Libraries" block
- Click the "+" button and select ``libDailymotionSDK.a`` library
- Click the "+" button again and select the ``Security.framework``
- Click the "+" button again and select the ``SystemConfiguration.framework``


Add headers
~~~~~~~~~~~

- Open the "Build Settings" tab
- Locate the "Other Linker Flags" setting and add the ``-ObjC`` and ``-all_load`` flags
- Locate "Header Search Paths" (and not "User Header Search Paths") and add two settings: ``"$(TARGET_BUILD_DIR)/usr/local/lib/include"`` and ``"$(OBJROOT)/UninstalledProducts/include"``. Make sure to include the quotes here and are plain double quote (not typographic quotes).

Import headers in your source files
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

In the source files where you need to use the library, use #import ``<DailymotionSDK/DailymotionSDK.h>``::

    #import <DailymotionSDK/SDK.h>


Feedback
--------

We are relying on the [GitHub issues tracker][issues] linked from above for feedback. File bugs or
other issues http://github.com/dailymotion/dailymotion-sdk-objc/issues

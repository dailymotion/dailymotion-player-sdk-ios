###########################
Dailymotion Objective-C SDK
###########################

This repository contains the official open source Objective-C SDK that allows you to access the Dailymotion API from your Mac OS X or iOS application.

For a complete list of available methods, see http://www.dailymotion.com/doc/api/advanced-api-reference.html

=====
Usage
=====

Authenticate
------------

The Dailymotion API requires OAuth 2.0 authentication in order to be used. This library implements three granting methods of OAuth 2.0 for different kinds of usages.

Authorization Grant Type
^^^^^^^^^^^^^^^^^^^^^^^^

This mode is the mode you should use in most cases. In this mode an ``UIWebView`` under iOS or a ``WebView`` on Mac OS X is opened with an authorization page presented to the end-user.

Here is a usage example::

    dailymotion = [[Dailymotion alloc] init];
    dailymotion.UIDelegate = self;
    [dailymotion setGrantType:DailymotionGrantTypeAuthorization
                   withAPIKey:apiKey secret:apiSecret scope:@"read"];
    [dailymotion callMethod:method withArguments:arguments delegate:self];

You have to implement the DailymotionUIDelegate protocol in order to show user a modal dialog to the end-user asking for permission to link your application with his account. The ``dailymotion:createModalDialogWithView:`` method instructs the delegate to show the given view to the user. You have the choice to show this view in a separate window or as part of you application UI. The ``dailymotionCloseModalDialog:`` method is called when the modal dialog should be closed once the authentication has been completed.

Password Grant Type
^^^^^^^^^^^^^^^^^^^

If the authorization grant type doesn't suits your application workflow, you can request end-user credentials and use the password grant type to authenticate requests. Note that you MUST NOT store end-user credentials.

Here is a usage example::

    dailymotion = [[Dailymotion alloc] init];
    dailymotion.UIDelegate = self;
    [dailymotion setGrantType:DailymotionGrantTypePassword
                   withAPIKey:apiKey secret:apiSecret scope:@"read"];
    [dailymotion callMethod:method withArguments:arguments delegate:self];

You have to implement the DailymotionUIDelegate protocol in order to be asked by the API when to request end-user credentials via the ``dailymotionDidRequestUserCredentials:`` method. In response, you will call the ``setUsername:password:`` method with user credentials once you got them.

Client Credentials Grant Type
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

If you don't need to access the Dailymotion API on behalf of a user because, for instance, you plan to
only access public data, you can use the client credentials grant type. With this grant type, you will only have
access to public data or private date of the user owning the API key.

Here is a usage example::

    dailymotion = [[Dailymotion alloc] init];
    [dailymotion setGrantType:DailymotionGrantTypeClientCredentials
                   withAPIKey:apiKey secret:apiSecret scope:@"read"];
    [dailymotion callMethod:method withArguments:arguments delegate:self];

File Upload
-----------

Certain methods like ``video.upload`` requires a URL to a file. To create those URLs, the ``uploadFile:delegate:`` method have to be used like this::

    [dailymotion uploadFile:@"/path/to/file.mp4" delegate:self];

You have to implement the ``dailymotion:didUploadFileAtURL:`` delegate method to get the URL returned by the server. You can then use this URL as an argument to methods requiring such parameter. For instance to create a video::

    - (void)dailymotion:(Dailymotion *)dailymotion didUploadFileAtURL:(NSURL *)URL;
    {
        [dailymotion callMethod:@"video.create"
                  withArguments:[NSDictionary dictionaryWithObject:[URL absoluteString] forKey:@"url"]
                       delegate:self];
    }

In case of error, the ``dailymotion:didReturnError:userInfo:`` will be called. To implement progress indicator, you can implement the ``dailymotion:didSendFileData:totalBytesWritten:totalBytesExpectedToWrite:`` delegate method.

Feedback
--------

We are relying on the [GitHub issues tracker][issues] linked from above for feedback. File bugs or
other issues [here][issues].

[issues]: http://github.com/dailymotion/dailymotion-sdk-objc/issues

The Dailymotion SDK allows you to access the Dailymotion API and control the Dailymotion HTML 5 player from Mac OS X or iOS.

*WARNING*: This SDK requires a 5.0 minimum deployement version for iOS.

# Useful Resources

- Dailymotion SDK: https://github.com/dailymotion/dailymotion-sdk-objc
- Dailymotion API Reference: http://www.dailymotion.com/doc/api/reference.html
- Dailymotion API Explorer: http://www.dailymotion.com/doc/api/explorer

## Player API

The Dailymotion SDK let you control the Dailymotion HTML 5 player from you app.

Here is an example of player instanciation:

    self.playerController = playerViewController = [DMAPI.sharedAPI playerWithVideo:@"xkdk2" params:nil];
    self.playerController.delegate = self;
    [self.view addSubview:self.playerController.view];
    [self.playerViewController play];
    ...

For working example, see [VideoList Sample](https://github.com/dailymotion/dailymotion-sdk-objc/tree/master/Examples/VideoListSample) app.

## UIKit integration

The easiest way to use the Dailymotion SDK is to use UIKit integration classes. They are high level integration of the Dailymotion API into UIKit components like `UITableViewController`, `UICollectionViewController` or `UIPageViewController`. They handle for you all the boilerplate code for data loading, infinite scrolling pagination, data caching and cache invalidation.

- See DMItemTableViewController for `UITableViewController` implementation
- See DMItemCollectionViewController for `UICollectionViewController` implementation
- See DMItemPageViewDataSourceDelegate for `UIPageViewController` implementation
- See DMItemPickerLabel for `UIPickerLabel` implementation

For working example, see [VideoList Sample](https://github.com/dailymotion/dailymotion-sdk-objc/tree/master/Examples/VideoListSample) app.

## Model Classes

The DMItem and DMItemCollection high level classes that wrap the DMAPI class. They perform the correct CRUDL API requests for given remote Dailymotion object and handle the caching and cache invalidation of the returned data.

You should always prefer using those classe over performing raw API calls using DMAPI.

### Examples

Gather metadata of a video:

    DMItem *video = [DMItem itemWithType:@"video" forId:@"x1k3d"];

    [video withFields:@[@"title", @"description", @"owner.screenname"] do:^(NSDictionary *data , BOOL stalled , NSError *error)
    {
        NSLog(@"Video %@ as title \"%@\" and is owned by \"%@\"", data[@"title"], data[@"owner.screenname"]);
    }];

Edit video metadata:

    DMItem *video = [DMItem itemWithType:@"video" forId:@"x1k3d"];

    [video editWithData:@{@"title": @"new title"} done:^(NSError *error)
    {
        // handle error
    }];

Performing search:

    NSDictionary *args = @{@"search": @"a search query", @"sort": @"relevance"};
    DMItemRemoteCollection *searchCollection = [DMItemCollection itemCollectionWithType:@"video" forParams:args];
    [searchCollection itemsWithFields:@[@"id", @"title"] forPage:1 withPageSize:20 do:^(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error)
    {
        if (!stalled)
        {
            for (NSDictionary *data in items)
            {
                NSLog(@"title: %@", data[@"title"]);
            }
        }
    }];

Gathering public playlist of a given user:

    DMItem *user = [DMItem itemWithType:@"user" forId:@"plidujeanzzz"];
    DMItemCollection *playlistCollection = [user itemCollectionWithConnection:@"playlists" ofType:@"playlist"];
    [searchCollection playlistCollection:@[@"id", @"name"] forPage:1 withPageSize:20 do:^(NSArray *items, BOOL more, NSInteger total, BOOL stalled, NSError *error)
    {
        if (!stalled)
        {
            for (NSDictionary *data in items)
            {
                NSLog(@"playlit name: %@", data[@"name"]);
            }
        }
    }];

## Raw API Access

If you need to perform raw request to the API, you can use the DMAPI class. The DMAPI class handle asynchronous API calls using blocks. If several API calls are perform within the same run loop tic, they are automatically aggregated into a single HTTP request.

Here are some example of DMAPI usage:

Gather metadata of a video:

    NSDictionary *args = @{@"fields": @[@"title", @"owner.screenname"]};
    [DMAPI.sharedAPI get:@"/video/x12k3" args:args callback:^(NSDictionary *data, DMAPICacheInfo *cacheInfo, NSError *error)
    {
        NSLog(@"Video %@ as title \"%@\" and is owned by \"%@\"", data[@"title"], data[@"owner.screenname"]);
    }];

## Authentication

If you need to access the Dailymotion API on behalf of a user, you'll need to create an API key and authenticate the user using OAuth 2.0. You can instruct the Dailymotion SDK to use OAuth 2.0 to authenticate your user by changing the OAuth grant type as follow:

    DMAPI.sharedAPI.oauth.delegate = self; // You need to implement DailymotionOAuthDelegate protocol
    [DMAPI.sharedAPI.oauth setGrantType:DailymotionGrantTypeAuthorization
                             withAPIKey:@"your API key here"
                                 secret:@"your API secret here"
                                  scope:@"email manage_playlists"];
    [DMAPI.sharedAPI get:@"/me" callback:^(NSDictionary *data, DMAPICacheInfo *cacheInfo, NSError *error)
    {
        if (!error)
        {
            // Here, the user is authenticated
        }
    }];

See the [Uploader Sample](https://github.com/dailymotion/dailymotion-sdk-objc/tree/master/Examples/UploaderSample) app for an example implementation.

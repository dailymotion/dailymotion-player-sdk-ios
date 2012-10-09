The Dailymotion SDK allows you to access the Dailymotion API and control the Dailymotion HTML 5 player from Mac OS X or iOS.

*WARNING*: This SDK requires a 5.0 minimum deployement version for iOS.

## UIKit integration

The easiest way to use the Dailymotion SDK is to use UIKit integration classes. They are high level integration of the Dailymotion API into UIKit components like `UITableViewController`, `UICollectionViewController` or `UIPageViewController`. They handle for you all the boilerplate code for data loading, infinite scrolling pagination, data caching and cache invalidation.

- See DMItemTableViewController for `UITableViewController` implementation
- See DMItemCollectionViewController for `UICollectionViewController` implementation
- See DMItemPageViewDataSourceDelegate for `UIPageViewController` implementation
- See DMItemPickerLabel for `UIPickerLabel` implementation

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





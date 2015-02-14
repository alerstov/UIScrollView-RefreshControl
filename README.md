# UIScrollView-RefreshControl
IOS7-like refresh control in any UIScrollView for IOS5+

## Usage
```
#import "UIScrollView+RefershControl.h"

[scrollView enableRefreshingWithHandler:^{
    // some refresh operation
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [scrollView endRefreshing];
    });
}];
```

## Resources
*  [Custom activity indicators using a replicator layer](http://ronnqvi.st/custom-activity-indicators-using-a-replicator-layer/)

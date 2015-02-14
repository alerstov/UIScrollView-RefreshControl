//
//  ViewController.m
//  RefreshControlExample
//
//  Created by Alexander Stepanov on 2/15/15.
//  Copyright (c) 2015 Alexander Stepanov. All rights reserved.
//

#import "ViewController.h"
#import "UIScrollView+RefershControl.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.scrollView.contentSize = self.view.frame.size;
    
    [self.scrollView enableRefreshingWithHandler:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.scrollView endRefreshing];
        });
    }];
}

@end

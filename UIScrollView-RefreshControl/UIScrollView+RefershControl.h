//
//  UIScrollView+RefershControl.h
//  RefershControl
//
//  Created by Alexander Stepanov on 2/13/15.
//  Copyright (c) 2015 Alexander Stepanov. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIScrollView (RefershControl)

@property (nonatomic, readonly) BOOL refreshing;

-(void)enableRefreshingWithHandler:(void(^)(void))handler;
-(void)endRefreshing;

@end

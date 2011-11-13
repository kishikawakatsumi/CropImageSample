//
//  ImageViewController.m
//  CropImageSample
//
//  Created by Kishikawa Katsumi on 11/11/14.
//  Copyright (c) 2011 Kishikawa Katsumi. All rights reserved.
//

#import "ImageViewController.h"

@implementation ImageViewController

@synthesize imageView;
@synthesize image;

- (void)dealloc {
    self.imageView = nil;
    self.image = nil;
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = NSLocalizedString(@"Cropped Image", nil);
    
    imageView.image = image;
}
							
@end

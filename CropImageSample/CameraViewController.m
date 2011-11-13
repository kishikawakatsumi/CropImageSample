//
//  CameraViewController.m
//  CropImageSample
//
//  Created by Kishikawa Katsumi on 11/11/14.
//  Copyright (c) 2011 Kishikawa Katsumi. All rights reserved.
//

#import "CameraViewController.h"
#import "ImageViewController.h"
#import "UIImage+Utilities.h"

#define IMAGE_WIDTH 612.0f
#define IMAGE_HEIGHT 612.0f

@implementation CameraViewController

@synthesize captureManager;
							
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    self.captureManager = nil;
    [super dealloc];
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationItem.title = NSLocalizedString(@"Camera", nil);
    
    NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
    [defaultCenter addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    
#if !TARGET_IPHONE_SIMULATOR
    NSError *error;
    self.captureManager = [[[CaptureManager alloc] init] autorelease];
    captureManager.delegate = self;
    if ([captureManager setupSessionWithPreset:AVCaptureSessionPresetPhoto error:&error]) {
        previewView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 320.0f, 372.0f)];
        previewView.backgroundColor = [UIColor blackColor];
        [self.view addSubview:previewView];
        [previewView release];
        
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToFocus:)];
        singleTap.numberOfTapsRequired = 1;
        singleTap.numberOfTouchesRequired = 1;
        [previewView addGestureRecognizer:singleTap];
        [singleTap release];
        
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToExpose:)];
        doubleTap.numberOfTapsRequired = 2;
        doubleTap.numberOfTouchesRequired = 1;
        [previewView addGestureRecognizer:doubleTap];
        [doubleTap release];
        
        [singleTap requireGestureRecognizerToFail:doubleTap];
        
        CGRect bounds = previewView.bounds;
        previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureManager.session];
        previewLayer.frame = bounds;
        previewLayer.hidden = YES;
        
        if (previewLayer.isOrientationSupported) {
            [previewLayer setOrientation:AVCaptureVideoOrientationPortrait];
        }
        
        previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        
        NSDictionary *unanimatedActions = [[NSDictionary alloc] initWithObjectsAndKeys:[NSNull null], @"bounds", [NSNull null], @"frame", [NSNull null], @"position", nil];
        
        focusBox = [CALayer layer];
        focusBox.actions = unanimatedActions;
        focusBox.borderWidth = 2.0f;
        focusBox.borderColor = [[UIColor colorWithRed:0.0f green:0.0f blue:1.0f alpha:0.8f] CGColor];
        focusBox.opacity = 0.0f;
        [previewLayer addSublayer:focusBox];
        
        exposeBox = [CALayer layer];
        exposeBox.actions = unanimatedActions;
        exposeBox.borderWidth = 2.0f;
        exposeBox.borderColor = [[UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:0.8f] CGColor];
        exposeBox.opacity = 0.0f;
        [previewLayer addSublayer:exposeBox];
        
        [unanimatedActions release];
        
        [previewView.layer addSublayer:previewLayer];
    }
#endif
    
    UIImageView *cropFrameView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"crop_frame.png"]];
    cropFrameView.alpha = 0.3f;
    [previewView addSubview:cropFrameView];
    [cropFrameView release];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [captureManager performSelector:@selector(startRunning) withObject:nil afterDelay:0.0];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    previewLayer.hidden = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [captureManager performSelector:@selector(stopRunning) withObject:nil afterDelay:0.0];
}

- (void)viewDidUnload {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    self.captureManager = nil;
    previewView = nil;
    previewLayer = nil;
    
    [super viewDidUnload];
}

#pragma mark -

- (void)showImagePicker {
    UIImagePickerController *pickerController = [[UIImagePickerController alloc] init];
    pickerController.delegate = self;
    pickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    pickerController.allowsEditing = YES;
    [self presentModalViewController:pickerController animated:YES];
    [pickerController release];
}

- (void)hideImagePickerAnimated:(BOOL)animated {
    [self dismissModalViewControllerAnimated:animated];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {	
    CGRect cropRect = [[info valueForKey:UIImagePickerControllerCropRect] CGRectValue];
    UIImage *originalImage = [info valueForKey:UIImagePickerControllerOriginalImage];
    
    cropRect = [originalImage convertCropRect:cropRect];
    
    UIImage *croppedImage = [originalImage croppedImage:cropRect];
    UIImage *resizedImage = [croppedImage resizedImage:CGSizeMake(IMAGE_WIDTH, IMAGE_HEIGHT) imageOrientation:originalImage.imageOrientation];
    
    ImageViewController *controller = [[ImageViewController alloc] init];
    controller.image = resizedImage;
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
    
    [self hideImagePickerAnimated:NO];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self hideImagePickerAnimated:YES];
}

#pragma mark -

- (void)captureStillImageFinished:(UIImage *)image {
    CGSize imageSize = image.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGRect cropRect;
    if (height > width) {
        cropRect = CGRectMake((height - width) / 2.0f, 0.0f, width, width);
    } else {
        cropRect = CGRectMake((width - height) / 2.0f, 0.0f, width, width);
    }
    
    UIImage *croppedImage = [image croppedImage:cropRect];
    UIImage *resizedImage = [croppedImage resizedImage:CGSizeMake(IMAGE_WIDTH, IMAGE_HEIGHT) imageOrientation:image.imageOrientation];
    
    ImageViewController *controller = [[ImageViewController alloc] init];
    controller.image = resizedImage;
    [self.navigationController pushViewController:controller animated:YES];
    [controller release];
    
    processingTakePhoto = NO;
}

- (IBAction)shutterButtonPushed:(id)sender {
    if (processingTakePhoto) {
        return;
    }
    processingTakePhoto = YES;
    
#if !TARGET_IPHONE_SIMULATOR
    [captureManager captureStillImage];
#endif
}

- (IBAction)photoAlbumButtonPushed:(id)sender {
    previewLayer.hidden = YES;
    [captureManager stopRunning];
    [self performSelector:@selector(showImagePicker) withObject:nil afterDelay:0.0];
}

#pragma mark -

- (void)captureSessionDidStartRunning {
    previewLayer.hidden = NO;
    
    CGRect bounds = previewView.bounds;
    CGPoint screenCenter = CGPointMake(bounds.size.width / 2.0f, bounds.size.height / 2.0f);
    [self drawFocusBoxAtPointOfInterest:screenCenter];
    [self drawExposeBoxAtPointOfInterest:screenCenter];
}

#pragma mark -

+ (void)addAdjustingAnimationToLayer:(CALayer *)layer removeAnimation:(BOOL)remove {
    if (remove) {
        [layer removeAnimationForKey:@"animateOpacity"];
    }
    if ([layer animationForKey:@"animateOpacity"] == nil) {
        [layer setHidden:NO];
        CABasicAnimation *opacityAnimation = [CABasicAnimation animationWithKeyPath:@"opacity"];
        [opacityAnimation setDuration:0.3f];
        [opacityAnimation setRepeatCount:1.0f];
        [opacityAnimation setAutoreverses:YES];
        [opacityAnimation setFromValue:[NSNumber numberWithFloat:1.0f]];
        [opacityAnimation setToValue:[NSNumber numberWithFloat:0.0f]];
        [layer addAnimation:opacityAnimation forKey:@"animateOpacity"];
    }
}

- (void)drawFocusBoxAtPointOfInterest:(CGPoint)point {
    if ([captureManager hasFocus]) {
        [focusBox setFrame:CGRectMake(0.0f, 0.0f, 80.0f, 80.0f)];
        [focusBox setPosition:point];
        [CameraViewController addAdjustingAnimationToLayer:focusBox removeAnimation:YES];
    }    
}

- (void)drawExposeBoxAtPointOfInterest:(CGPoint)point {
    if ([captureManager hasExposure]) {        
        [exposeBox setFrame:CGRectMake(0.0f, 0.0f, 114.0f, 114.0f)];
        [exposeBox setPosition:point];
        [CameraViewController addAdjustingAnimationToLayer:exposeBox removeAnimation:YES];
    }    
}

- (CGPoint)convertToPointOfInterestFromViewCoordinates:(CGPoint)viewCoordinates {
    CGPoint pointOfInterest = CGPointMake(0.5f, 0.5f);
    CGSize frameSize = previewView.frame.size;
    
    AVCaptureVideoPreviewLayer *videoPreviewLayer = previewLayer;
    
    if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResize]) {
        pointOfInterest = CGPointMake(viewCoordinates.y / frameSize.height, 1.0f - (viewCoordinates.x / frameSize.width));
    } else {
        CGRect cleanAperture;
        for (AVCaptureInputPort *port in captureManager.videoInput.ports) {
            if ([port mediaType] == AVMediaTypeVideo) {
                cleanAperture = CMVideoFormatDescriptionGetCleanAperture([port formatDescription], YES);
                CGSize apertureSize = cleanAperture.size;
                CGPoint point = viewCoordinates;
                
                CGFloat apertureRatio = apertureSize.height / apertureSize.width;
                CGFloat viewRatio = frameSize.width / frameSize.height;
                CGFloat xc = 0.5f;
                CGFloat yc = 0.5f;
                
                if ( [[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspect] ) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = frameSize.height;
                        CGFloat x2 = frameSize.height * apertureRatio;
                        CGFloat x1 = frameSize.width;
                        CGFloat blackBar = (x1 - x2) / 2;
                        if (point.x >= blackBar && point.x <= blackBar + x2) {
                            xc = point.y / y2;
                            yc = 1.0f - ((point.x - blackBar) / x2);
                        }
                    } else {
                        CGFloat y2 = frameSize.width / apertureRatio;
                        CGFloat y1 = frameSize.height;
                        CGFloat x2 = frameSize.width;
                        CGFloat blackBar = (y1 - y2) / 2;
                        if (point.y >= blackBar && point.y <= blackBar + y2) {
                            xc = ((point.y - blackBar) / y2);
                            yc = 1.0f - (point.x / x2);
                        }
                    }
                } else if ([[videoPreviewLayer videoGravity] isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                    if (viewRatio > apertureRatio) {
                        CGFloat y2 = apertureSize.width * (frameSize.width / apertureSize.height);
                        xc = (point.y + ((y2 - frameSize.height) / 2.0f)) / y2;
                        yc = (frameSize.width - point.x) / frameSize.width;
                    } else {
                        CGFloat x2 = apertureSize.height * (frameSize.height / apertureSize.width);
                        yc = 1.0f - ((point.x + ((x2 - frameSize.width) / 2)) / x2);
                        xc = point.y / frameSize.height;
                    }
                }
                
                pointOfInterest = CGPointMake(xc, yc);
                break;
            }
        }
    }
    
    return pointOfInterest;
}

#pragma mark -

- (void)tapToFocus:(UIGestureRecognizer *)recognizer {
    CGPoint point = [recognizer locationInView:previewView];
    if (captureManager.videoInput.device.isFocusPointOfInterestSupported) {
        CGPoint convertedFocusPoint = [self convertToPointOfInterestFromViewCoordinates:point];
        [captureManager focusAtPoint:convertedFocusPoint];
        [self drawFocusBoxAtPointOfInterest:point];
    }
}

- (void)tapToExpose:(UIGestureRecognizer *)recognizer {
    CGPoint point = [recognizer locationInView:previewView];
    if (captureManager.videoInput.device.isExposurePointOfInterestSupported) {
        CGPoint convertedExposurePoint = [self convertToPointOfInterestFromViewCoordinates:point];
        [captureManager exposureAtPoint:convertedExposurePoint];
        [self drawExposeBoxAtPointOfInterest:point];
    }
}

- (void)resetFocusAndExpose:(UIGestureRecognizer *)recognizer {
    CGPoint pointOfInterest = CGPointMake(0.5f, 0.5f);
    [captureManager focusAtPoint:pointOfInterest];
    [captureManager exposureAtPoint:pointOfInterest];
    
    CGRect bounds = previewView.bounds;
    CGPoint screenCenter = CGPointMake(bounds.size.width / 2.0f, bounds.size.height / 2.0f);
    
    [self drawFocusBoxAtPointOfInterest:screenCenter];
    [self drawExposeBoxAtPointOfInterest:screenCenter];
    
    [captureManager setFocusMode:AVCaptureFocusModeContinuousAutoFocus];
}

#pragma mark -

- (void)applicationDidEnterBackground:(NSNotification *)note {
    UIViewController *modalViewController = self.modalViewController;
    if (modalViewController) {
        [modalViewController dismissModalViewControllerAnimated:NO];
    }
}

@end

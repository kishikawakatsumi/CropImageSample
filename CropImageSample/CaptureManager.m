//
//  FFCaptureManager.m
//  FoodFlow
//
//  Created by Kishikawa Katsumi on 11/08/18.
//  Copyright 2011 Kishikawa Katsumi. All rights reserved.
//

#import "CaptureManager.h"

@interface CaptureManager(AVCaptureFileOutputRecordingDelegate)<AVCaptureFileOutputRecordingDelegate>
@end


@interface CaptureManager()

@property (nonatomic, retain) AVCaptureSession *session;
@property (nonatomic, retain) AVCaptureDeviceInput *videoInput;
@property (nonatomic, retain) AVCaptureStillImageOutput *stillImageOutput;

@end

@interface CaptureManager(Internal)

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position;
- (AVCaptureDevice *)frontFacingCamera;
- (AVCaptureDevice *)backFacingCamera;

@end

@implementation CaptureManager

@synthesize session;
@synthesize videoInput;
@synthesize stillImageOutput;
@dynamic flashMode;
@dynamic torchMode;
@dynamic focusMode;
@dynamic exposureMode;
@dynamic whiteBalanceMode;
@synthesize delegate;

- (id)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(captureSessionDidStartRunning:) name:AVCaptureSessionDidStartRunningNotification object:session];
    }
    
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [session stopRunning];
    self.session = nil;
    self.videoInput = nil;
    self.stillImageOutput = nil;
    [super dealloc];
}

- (BOOL)setupSessionWithPreset:(NSString *)sessionPreset error:(NSError **)error {
    videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:error];
    
    stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    stillImageOutput.outputSettings = [NSDictionary dictionaryWithObjectsAndKeys:AVVideoCodecJPEG, AVVideoCodecKey, nil];
    
    session = [[AVCaptureSession alloc] init];
    if ([session canAddInput:videoInput]) {
        [session addInput:videoInput];
    }
    if ([session canAddOutput:stillImageOutput]) {
        [session addOutput:stillImageOutput];
    }
    
    [session setSessionPreset:sessionPreset];
    
    return YES;
}

- (void)startRunning {
    [session startRunning];
}

- (void)stopRunning {
    [session stopRunning];
}

- (NSUInteger)cameraCount {
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count];
}

- (void)captureStillImage { 
    AVCaptureConnection *videoConnection = [CaptureManager connectionWithMediaType:AVMediaTypeVideo fromConnections:stillImageOutput.connections];
    if ([videoConnection isVideoOrientationSupported]) {
        [videoConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    }
    
    [stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection
                                                  completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error)
     {
         [session stopRunning];
         
         if (imageDataSampleBuffer != NULL) {
             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
             UIImage *image = [[UIImage alloc] initWithData:imageData];
             
             if ([delegate respondsToSelector:@selector(captureStillImageFinished:)]) {
                 [delegate captureStillImageFinished:image];
             }
             
             [image release];
         } else if (error) {
             if ([delegate respondsToSelector:@selector(captureStillImageFailedWithError:)]) {
                 [delegate captureStillImageFailedWithError:error];
             }
         }
     }];
}

- (BOOL)cameraToggle {
    BOOL success = NO;
    
    if ([self hasMultipleCameras]) {
        NSError *error;
        AVCaptureDeviceInput *newVideoInput;
        AVCaptureDevicePosition position = videoInput.device.position;
        if (position == AVCaptureDevicePositionBack) {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self frontFacingCamera] error:&error];
        } else if (position == AVCaptureDevicePositionFront) {
            newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self backFacingCamera] error:&error];
        } else {
            goto bail;
        }
        
        if (newVideoInput != nil) {
            [session beginConfiguration];
            [session removeInput:videoInput];
            if ([session canAddInput:newVideoInput]) {
                [session addInput:newVideoInput];
                self.videoInput = newVideoInput;
            } else {
                [session addInput:videoInput];
            }
            [session commitConfiguration];
            success = YES;
            [newVideoInput release];
        } else if (error) {
            if ([delegate respondsToSelector:@selector(someOtherError:)]) {
                [delegate someOtherError:error];
            }
        }
    }
    
bail:
    return success;
}

- (BOOL)hasMultipleCameras {
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1 ? YES : NO;
}

- (BOOL)hasFlash {
    return videoInput.device.hasFlash;
}

- (AVCaptureFlashMode)flashMode {
    return videoInput.device.flashMode;
}

- (void)setFlashMode:(AVCaptureFlashMode)flashMode {
    AVCaptureDevice *device = videoInput.device;
    if ([device isFlashModeSupported:flashMode] && device.flashMode != flashMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.flashMode = flashMode;
            [device unlockForConfiguration];
        } else {
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }    
    }
}

- (BOOL)hasTorch {
    return videoInput.device.hasTorch;
}

- (AVCaptureTorchMode)torchMode {
    return videoInput.device.torchMode;
}

- (void)setTorchMode:(AVCaptureTorchMode)torchMode {
    AVCaptureDevice *device = videoInput.device;
    if ([device isTorchModeSupported:torchMode] && device.torchMode != torchMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.torchMode = torchMode;
            [device unlockForConfiguration];
        } else {
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

- (BOOL)hasFocus {
    AVCaptureDevice *device = videoInput.device;
    
    return  [device isFocusModeSupported:AVCaptureFocusModeLocked] || 
    [device isFocusModeSupported:AVCaptureFocusModeAutoFocus] || 
    [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus];
}

- (AVCaptureFocusMode)focusMode {
    return videoInput.device.focusMode;
}

- (void)setFocusMode:(AVCaptureFocusMode)focusMode {
    AVCaptureDevice *device = videoInput.device;
    if ([device isFocusModeSupported:focusMode] && device.focusMode != focusMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.focusMode = focusMode;
            [device unlockForConfiguration];
        } else {
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }    
    }
}

- (BOOL)hasExposure {
    AVCaptureDevice *device = videoInput.device;
    
    return  [device isExposureModeSupported:AVCaptureExposureModeLocked] ||
    [device isExposureModeSupported:AVCaptureExposureModeAutoExpose] ||
    [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure];
}

- (AVCaptureExposureMode)exposureMode {
    return videoInput.device.exposureMode;
}

- (void)setExposureMode:(AVCaptureExposureMode)exposureMode {
    if (exposureMode == AVCaptureExposureModeAutoExpose) {
        exposureMode = AVCaptureExposureModeContinuousAutoExposure;
    }
    AVCaptureDevice *device = videoInput.device;
    if ([device isExposureModeSupported:exposureMode] && device.exposureMode != exposureMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.exposureMode = exposureMode;
            [device unlockForConfiguration];
        } else {
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

- (BOOL)hasWhiteBalance {
    AVCaptureDevice *device = videoInput.device;
    
    return  [device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeLocked] ||
    [device isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeAutoWhiteBalance];
}

- (AVCaptureWhiteBalanceMode)whiteBalanceMode {
    return videoInput.device.whiteBalanceMode;
}

- (void)setWhiteBalanceMode:(AVCaptureWhiteBalanceMode)whiteBalanceMode {
    if (whiteBalanceMode == AVCaptureWhiteBalanceModeAutoWhiteBalance) {
        whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
    }    
    AVCaptureDevice *device = videoInput.device;
    if ([device isWhiteBalanceModeSupported:whiteBalanceMode] && device.whiteBalanceMode != whiteBalanceMode) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.whiteBalanceMode = whiteBalanceMode;
            [device unlockForConfiguration];
        } else {
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

- (void)focusAtPoint:(CGPoint)point {
    AVCaptureDevice *device = videoInput.device;
    if (device.isFocusPointOfInterestSupported && [device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.focusPointOfInterest = point;
            device.focusMode = AVCaptureFocusModeAutoFocus;
            [device unlockForConfiguration];
        } else {
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }        
    }
}

- (void)exposureAtPoint:(CGPoint)point {
    AVCaptureDevice *device = videoInput.device;
    if (device.isExposurePointOfInterestSupported && [device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            device.exposurePointOfInterest = point;
            device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
            [device unlockForConfiguration];
        } else {
            if ([delegate respondsToSelector:@selector(acquiringDeviceLockFailedWithError:)]) {
                [delegate acquiringDeviceLockFailedWithError:error];
            }
        }
    }
}

+ (AVCaptureConnection *)connectionWithMediaType:(NSString *)mediaType fromConnections:(NSArray *)connections {
	for (AVCaptureConnection *connection in connections) {
		for (AVCaptureInputPort *port in [connection inputPorts]) {
			if ([port.mediaType isEqual:mediaType] ) {
				return [[connection retain] autorelease];
			}
		}
	}
	return nil;
}

- (void)captureSessionDidStartRunning:(NSNotification *)note {
    if ([delegate respondsToSelector:@selector(captureSessionDidStartRunning)]) {
        [delegate captureSessionDidStartRunning];
    }
}

@end

@implementation CaptureManager(Internal)

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == position) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *)frontFacingCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionFront];
}

- (AVCaptureDevice *)backFacingCamera {
    return [self cameraWithPosition:AVCaptureDevicePositionBack];
}

@end

//
//  ViewController.m
//  WhenInUse
//
//  Created by Jesse Bounds on 10/4/16.
//  Copyright © 2016 Rebounds. All rights reserved.
//

#import "ViewController.h"

@import CoreLocation;

@interface ViewController () <UIPickerViewDataSource,
                              UIPickerViewDelegate,
                              CLLocationManagerDelegate>

@property (weak, nonatomic) IBOutlet UIPickerView *accuracyPickerView;
@property (weak, nonatomic) IBOutlet UITextField *distanceFilterTextField;
@property (nonatomic) CLLocationManager *locationManager;
@property (nonatomic) NSArray *locationAccuracies;
@property (weak, nonatomic) IBOutlet UIView *statusView;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *stopButton;
@property (weak, nonatomic) IBOutlet UIButton *clearButton;
@property (nonatomic) NSDateFormatter *dateFormatter;
@property (nonatomic) dispatch_queue_t debugLogSerialQueue;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.accuracyPickerView.delegate = self;
    self.accuracyPickerView.dataSource = self;
    
    self.locationAccuracies = @[@"kCLLocationAccuracyBest",
                                @"kCLLocationAccuracyNearestTenMeters",
                                @"kCLLocationAccuracyHundredMeters",
                                @"kCLLocationAccuracyKilometer",
                                @"kCLLocationAccuracyThreeKilometers"];
    
    self.statusView.layer.cornerRadius = CGRectGetWidth(self.statusView.frame) / 2.0;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self.locationManager requestWhenInUseAuthorization];
}

- (void)resumeLocationDataCollection {
    CLLocationDistance locationDistanceFilter = [self.distanceFilterTextField.text doubleValue];
    CLLocationAccuracy locationAccuracy = [self locationAccuracy];
    self.locationManager.distanceFilter = locationDistanceFilter;
    self.locationManager.desiredAccuracy = locationAccuracy;
    [self.locationManager startUpdatingLocation];
}

- (CLLocationAccuracy)locationAccuracy {
    switch ([self.accuracyPickerView selectedRowInComponent:0]) {
        case 0:
            return kCLLocationAccuracyBest;
            break;
        case 1:
            return kCLLocationAccuracyNearestTenMeters;
            break;
        case 2:
            return kCLLocationAccuracyHundredMeters;
            break;
        case 3:
            return kCLLocationAccuracyKilometer;
            break;
        default:
            return kCLLocationAccuracyThreeKilometers;
            break;
    }    
    return 0;
}

- (void)writeLocationToLocalDebugLog:(CLLocation *)location {
    if (!self.debugLogSerialQueue) {
        self.debugLogSerialQueue = dispatch_queue_create("events.debugLog", DISPATCH_QUEUE_SERIAL);
    }
    
    dispatch_async(self.debugLogSerialQueue, ^{
        NSDictionary *locationObject = @{@"logTime": @([[NSDate date] timeIntervalSince1970]),
                                         @"locationTime": @([location.timestamp timeIntervalSince1970]),
                                         @"lat": @(location.coordinate.latitude),
                                         @"lon": @(location.coordinate.longitude)};
        NSLog(@"%@", locationObject);
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:locationObject options:NSJSONWritingPrettyPrinted error:nil];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        jsonString = [jsonString stringByAppendingString:@",\n"];
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        if ([fileManager fileExistsAtPath:[self logFilePath]]) {
            NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:[self logFilePath]];
            [fileHandle seekToEndOfFile];
            [fileHandle writeData:[jsonString dataUsingEncoding:NSUTF8StringEncoding]];
        } else {
            [fileManager createFileAtPath:[self logFilePath] contents:[jsonString dataUsingEncoding:NSUTF8StringEncoding] attributes:@{ NSFileProtectionKey: NSFileProtectionCompleteUntilFirstUserAuthentication }];
        }
    });
}

#pragma mark - Actions

- (IBAction)didTapStartButton:(id)sender {
    [self.distanceFilterTextField resignFirstResponder];
    self.startButton.enabled = NO;
    self.statusView.backgroundColor = [UIColor greenColor];
    self.statusView.alpha = 0.25;
    [self resumeLocationDataCollection];
}

- (IBAction)didTapStopButton:(id)sender {
    self.startButton.enabled = YES;
    self.statusView.backgroundColor = [UIColor lightGrayColor];
    self.statusView.alpha = 1.0;
    [self.locationManager stopUpdatingLocation];
}

- (IBAction)didTapClearButton:(id)sender {
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    if ([fileManager fileExistsAtPath:[self logFilePath]]) {
        [fileManager removeItemAtPath:[self logFilePath] error:nil];
    }
}

- (NSString *)logFilePath {
    NSString *logFilePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent: @"wheninuse_log.json"];
    return logFilePath;
}

#pragma mark - UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return 5;
}

#pragma mark - UIPickerViewDelegate

- (nullable NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return self.locationAccuracies[row];
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    for (CLLocation *location in locations) {
        [self writeLocationToLocalDebugLog:location];
    }
    
    [self.statusView.layer removeAllAnimations];
    self.statusView.alpha = 1.0;
    [UIView animateWithDuration:0.75 animations:^{
        self.statusView.alpha = 0.25;
    }];
}

@end

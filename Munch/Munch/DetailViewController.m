//
//  DetailViewController.m
//  Munch
//
//  Created by Enoch Ng on 2016-06-01.
//  Copyright © 2016 Enoch Ng. All rights reserved.
//

#import "DetailViewController.h"

@interface DetailViewController () <CLLocationManagerDelegate, MKMapViewDelegate>

@property (weak, nonatomic) IBOutlet UIButton *callButton;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic) float *distance;

@property (nonatomic) NSString *phoneNumberURLString;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *addressLabel;
@property (weak, nonatomic) IBOutlet UIImageView *ratingImage;
@property (weak, nonatomic) IBOutlet UILabel *distanceLabel;

@property (nonatomic) MKDirectionsResponse *walking;
@property (nonatomic) MKDirectionsResponse *driving;
@property (nonatomic) BOOL isWalking;



@property (weak, nonatomic) IBOutlet UIView *buttonContainer;
@property (weak, nonatomic) IBOutlet UIView *callButtonContainerView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *callButtonLeadingConstraint;
@property (weak, nonatomic) IBOutlet UIView *munchNowContainerView;
@property (weak, nonatomic) IBOutlet UIButton *munchNowDynamicButton;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *hackViewWidthConstraint;




@end

@implementation DetailViewController

-(void)viewDidLoad{

    
    NSString *phoneNumber = self.receivedRestaurant.phoneNumber;
    if(phoneNumber) {
        self.phoneNumberURLString = [@"telprompt:://" stringByAppendingString:phoneNumber];
        [self.callButton addTarget:self action:@selector(holdDown:) forControlEvents:UIControlEventTouchDown];
        [self.callButton addTarget:self action:@selector(holdReleasePhone:) forControlEvents:UIControlEventTouchUpInside];
        [self.callButton addTarget:self action:@selector(holdReleaseOutside:) forControlEvents:UIControlEventTouchUpOutside];
        self.callButton.adjustsImageWhenHighlighted = NO;
    } else {
        self.callButton.enabled = NO;
    }
    
    [self.munchNowDynamicButton addTarget:self action:@selector(holdDown:) forControlEvents:UIControlEventTouchDown];
    [self.munchNowDynamicButton addTarget:self action:@selector(holdRelease:) forControlEvents:UIControlEventTouchUpInside];
    [self.munchNowDynamicButton addTarget:self action:@selector(holdReleaseOutside:) forControlEvents:UIControlEventTouchUpOutside];
    self.munchNowDynamicButton.adjustsImageWhenHighlighted = NO;
    

    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;

    if ([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined) {
        //remember to add mapkit and update plist with NSLocationWhenInUseUsageDescription
        [self.locationManager requestWhenInUseAuthorization];
    }

    [self createAnnots];
    
    self.imageView.image = self.receivedRestaurant.image;
    self.addressLabel.text = self.receivedRestaurant.address;
    self.nameLabel.text = self.receivedRestaurant.name;
    [ self downloadRatingImageForCardwithURLString:self.receivedRestaurant.ratingURL];

    MKCoordinateSpan span = MKCoordinateSpanMake(0.003, 0.003);
    MKCoordinateRegion region = MKCoordinateRegionMake(self.lastLocation.coordinate, span);
    [self.mapView setRegion:region animated:YES];
    
    self.mapView.showsPointsOfInterest = YES;
    
    self.isWalking = YES;

    
    if(self.showMunchNowButton){
        self.munchNowContainerView.alpha = 1.0;
        self.callButtonLeadingConstraint.constant = 0.0;
    } else {
        self.munchNowContainerView.alpha = 0.0;
       // self.callButtonLeadingConstraint.constant = self.buttonContainer.frame.size.width/2 - self.callButton.frame.size.width/2;
//        
        self.hackViewWidthConstraint.constant = self.buttonContainer.frame.size.width/4 - self.callButton.frame.size.width/2;
    }
    
}

-(void)viewDidAppear:(BOOL)animated{

   
    
    
        [self zoomToFitMapAnnotations:self.mapView];
    
    MKPlacemark *source = [[MKPlacemark alloc]initWithCoordinate:CLLocationCoordinate2DMake(self.lastLocation.coordinate.latitude, self.lastLocation.coordinate.longitude) addressDictionary:[NSDictionary dictionaryWithObjectsAndKeys:@"",@"", nil] ];
    
    MKMapItem *srcMapItem = [[MKMapItem alloc]initWithPlacemark:source];
    [srcMapItem setName:@""];
    
    MKPlacemark *destination = [[MKPlacemark alloc]initWithCoordinate:CLLocationCoordinate2DMake(self.receivedRestaurant.latitude, self.receivedRestaurant.longitude) addressDictionary:[NSDictionary dictionaryWithObjectsAndKeys:@"",@"", nil] ];
    
    MKMapItem *distMapItem = [[MKMapItem alloc]initWithPlacemark:destination];
    [distMapItem setName:@""];
    
    MKDirectionsRequest *request = [[MKDirectionsRequest alloc] init];
    request.source = srcMapItem;
    request.destination = distMapItem ;
    request.requestsAlternateRoutes = YES;
    request.transportType = MKDirectionsTransportTypeWalking;
    MKDirections *directions = [[MKDirections alloc] initWithRequest:request];
    [directions calculateDirectionsWithCompletionHandler:
     ^(MKDirectionsResponse *response, NSError *error) {
         if (error) {
             // Handle Error
             NSLog(@"error in walking");
         } else {
             self.walking = response;
             
             MKDirectionsRequest *request2 = [[MKDirectionsRequest alloc] init];
             request2.source = srcMapItem;
             request2.destination = distMapItem ;
             request2.requestsAlternateRoutes = YES;
             request2.transportType = MKDirectionsTransportTypeAutomobile;
             MKDirections *directions2 = [[MKDirections alloc] initWithRequest:request2];
             [directions2 calculateDirectionsWithCompletionHandler:
              ^(MKDirectionsResponse *response, NSError *error) {
                  if (error) {
                      // Handle Error
                      NSLog(@"error in driving");
                  } else {
                      self.driving = response;
                      
                      
                      
                      [self processRoutesToDetermineOnMap];
                  }
              }];
             
         }
     }];
    
}




-(void)processRoutesToDetermineOnMap
{
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"expectedTravelTime"
                                                                   ascending:YES];
    NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
    NSArray *sortedRoutesWalking = [self.walking.routes sortedArrayUsingDescriptors:sortDescriptors];
        MKRoute *walkingRoute = sortedRoutesWalking[0];

    float seconds = walkingRoute.expectedTravelTime;
    float minutes = seconds / 60;
    
    if(minutes < 30){
    self.distanceLabel.text = [NSString stringWithFormat:@"%1.0f mins",minutes];
        
        [self.mapView
         addOverlay:walkingRoute.polyline level:MKOverlayLevelAboveRoads];
    
    } else {
        
    NSArray *sortedRoutesDriving = [self.driving.routes sortedArrayUsingDescriptors:sortDescriptors];
    MKRoute *drivingRoute = sortedRoutesDriving[0];
       
        seconds = drivingRoute.expectedTravelTime;
        minutes = seconds / 60;
        float hours = minutes / 60;
        
        if(minutes < 60){
            
        self.distanceLabel.text = [NSString stringWithFormat:@"%1.0f min drive",minutes];
        [self.mapView
         addOverlay:drivingRoute.polyline level:MKOverlayLevelAboveRoads];
            
        } else {
            
            self.distanceLabel.text = [NSString stringWithFormat:@"%1.1f hr drive",hours];
            [self.mapView
             addOverlay:drivingRoute.polyline level:MKOverlayLevelAboveRoads];
        
        }
        
    }
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id < MKOverlay >)overlay
{
    MKPolylineRenderer *renderer =
    [[MKPolylineRenderer alloc] initWithOverlay:overlay];
    //renderer.strokeColor = [UIColor colorWithRed:0.32 green:0.62 blue:0.97 alpha:1.0];
    renderer.strokeColor = [UIColor grayColor];
    NSMutableArray * lineDash = [[NSMutableArray alloc] init];
    [lineDash addObject:[NSNumber numberWithInt:5]];
    [renderer setLineDashPattern:lineDash];
    renderer.lineWidth = 3.0;
    
    return renderer;
    
    
}

- (IBAction)backButtonPressed:(UIButton *)sender {

    [self dismissViewControllerAnimated:YES completion:^{
    }];


}


- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager
     didUpdateLocations:(NSArray<CLLocation *> *)locations {
    
    self.lastLocation = [locations lastObject];

}



-(void)holdDown:(UIButton *)sender{
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         sender.layer.transform = CATransform3DMakeScale(0.80,0.80, 1);
                     }
                     completion:^(BOOL finished) {
                     }];
    
}

-(void)holdReleasePhone:(UIButton *)sender{
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         sender.layer.transform = CATransform3DMakeScale(1.1,1.1, 1);
                     }
                     completion:^(BOOL finished) {
                         
                         [UIView animateWithDuration:0.05
                                               delay:0
                                             options:UIViewAnimationOptionCurveEaseOut
                                          animations:^{
                                              sender.layer.transform = CATransform3DMakeScale(1,1, 1);
                                          }
                                          completion:^(BOOL finished) {
                                              
                                              //makes phone call
                                              [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.phoneNumberURLString]];
                                              
                                              
                                          }];
                     }];
}

-(void)holdRelease:(UIButton *)sender{
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         sender.layer.transform = CATransform3DMakeScale(1.1,1.1, 1);
                     }
                     completion:^(BOOL finished) {
                         
                         [UIView animateWithDuration:0.05
                                               delay:0
                                             options:UIViewAnimationOptionCurveEaseOut
                                          animations:^{
                                              sender.layer.transform = CATransform3DMakeScale(1,1, 1);
                                          }
                                          completion:^(BOOL finished) {
                                              
                                          }];
                     }];
}

-(void)holdReleaseOutside:(UIButton *)sender{
    [UIView animateWithDuration:0.1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         sender.layer.transform = CATransform3DMakeScale(1.1,1.1, 1);
                     }
                     completion:^(BOOL finished) {
                         
                         [UIView animateWithDuration:0.05
                                               delay:0
                                             options:UIViewAnimationOptionCurveEaseOut
                                          animations:^{
                                              sender.layer.transform = CATransform3DMakeScale(1,1, 1);
                                          }
                                          completion:^(BOOL finished) {
                                          }];
                     }];
}


- (nullable MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id <MKAnnotation>)annotation {
    
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    
    MKAnnotationView *pin = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"Pin"];
    pin.image = [UIImage imageNamed:@"marker"];
    
    
    if (!pin) {
        pin = [[MKAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"Pin"];
        pin.canShowCallout = YES;
        pin.image = [UIImage imageNamed:@"marker"];
    }
    
    return pin;
}


-(void)createAnnots{
    
    MKPointAnnotation *newAnnot = [[MKPointAnnotation alloc] init];
    newAnnot.coordinate = CLLocationCoordinate2DMake(self.receivedRestaurant.latitude, self.receivedRestaurant.longitude);
    
    [self.mapView addAnnotation:newAnnot];
    
}

- (void)zoomToFitMapAnnotations:(MKMapView *)mapView {
    if ([mapView.annotations count] == 0) return;
    
    CLLocationCoordinate2D topLeftCoord;
    topLeftCoord.latitude = -90;
    topLeftCoord.longitude = 180;
    
    CLLocationCoordinate2D bottomRightCoord;
    bottomRightCoord.latitude = 90;
    bottomRightCoord.longitude = -180;
    
    for(id<MKAnnotation> annotation in mapView.annotations) {
        topLeftCoord.longitude = fmin(topLeftCoord.longitude, annotation.coordinate.longitude);
        topLeftCoord.latitude = fmax(topLeftCoord.latitude, annotation.coordinate.latitude);
        bottomRightCoord.longitude = fmax(bottomRightCoord.longitude, annotation.coordinate.longitude);
        bottomRightCoord.latitude = fmin(bottomRightCoord.latitude, annotation.coordinate.latitude);
    }
    
    topLeftCoord.longitude = fmin(topLeftCoord.longitude, self.lastLocation.coordinate.longitude);
    topLeftCoord.latitude = fmax(topLeftCoord.latitude, self.lastLocation.coordinate.latitude);
    bottomRightCoord.longitude = fmax(bottomRightCoord.longitude, self.lastLocation.coordinate.longitude);
    bottomRightCoord.latitude = fmin(bottomRightCoord.latitude,self.lastLocation.coordinate.latitude);
    
    MKCoordinateRegion region;
    region.center.latitude = topLeftCoord.latitude - (topLeftCoord.latitude - bottomRightCoord.latitude) * 0.5;
    region.center.longitude = topLeftCoord.longitude + (bottomRightCoord.longitude - topLeftCoord.longitude) * 0.5;
    
    // Add a little extra space on the sides
    region.span.latitudeDelta = fabs(topLeftCoord.latitude - bottomRightCoord.latitude) * 1.3;
    region.span.longitudeDelta = fabs(bottomRightCoord.longitude - topLeftCoord.longitude) * 1.3;
    
    region = [mapView regionThatFits:region];
    [mapView setRegion:region animated:YES];
}

-(void)downloadRatingImageForCardwithURLString:(NSString *)urlString{
    NSURLSessionTask *task = [[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlString] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (data) {
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.ratingImage.image = image;
                });
            }
        }
    }];
    [task resume];
    
}


- (IBAction)munchNowPressed:(UIButton *)sender {
    
    [UIView animateWithDuration:1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.munchNowContainerView.alpha = 0.0;
                     
                                             }
                     completion:^(BOOL finished) {
                        

                     }];
    

   // self.hackViewWidthConstraint.constant = self.buttonContainer.frame.size.width/2;
    
        [UIView animateWithDuration:1
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
//                         self.hackViewWidthConstraint.constant = self.view.frame.size.width/2 - self.callButton.frame.size.width;
                         self.callButtonContainerView.center = CGPointMake(self.view.frame.size.width/2 * 0.65,self.callButtonContainerView.center.y);
                         
                         [self.view setNeedsLayout];
                         
                     }
                     completion:^(BOOL finished) {
                     }];
}

@end

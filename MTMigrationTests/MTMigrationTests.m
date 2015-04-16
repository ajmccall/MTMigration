//
//  MTMigrationTests.m
//  MTMigrationTests
//
//  Created by Parker Wightman on 2/7/13.
//  Copyright (c) 2013 Mysterious Trousers. All rights reserved.
//

#import "MTMigrationTests.h"
#import "MTMigration.h"
#import <objc/runtime.h>

#define kDefaultWaitForExpectionsTimeout    2.0
#define kBundleShortVersionStringKey        @"CFBundleShortVersionString"
#define kBundleVersionKey                   @"CFBundleVersion"

@implementation MTMigrationTests

#define makr - Setup/TearDown

- (void)setUp {
    
    [super setUp];
    [self setUpMockBundle];
    [MTMigration reset];
}

- (void)setUpMockBundle {

    [self swapOutBundleMethods];
}

- (void)tearDown {
    
    [self tearDownMockBundle];
    [super tearDown];
}

- (void)tearDownMockBundle {
    
    [self swapInBundleMethods];
    [self setMainBundleAppBuild:nil];
    [self setMainBundleAppVersion:nil];
}

#pragma mark - Test migrateToVersion

- (void)testMigrationReset {
    
    [self setMainBundleAppVersion:@"1.0"];

    XCTestExpectation *expectingBlock1Run = [self expectationWithDescription:@"Expecting block to be run for version 0.9"];
	[MTMigration migrateToVersion:@"0.9" block:^{
        [expectingBlock1Run fulfill];
	}];
    
    XCTestExpectation *expectingBlock2Run = [self expectationWithDescription:@"Expecting block to be run for version 1.0"];
	[MTMigration migrateToVersion:@"1.0" block:^{
        [expectingBlock2Run fulfill];
	}];
	
	[MTMigration reset];

    XCTestExpectation *expectingBlock3Run = [self expectationWithDescription:@"Expecting block to be run AGAIN for version 0.9"];
	[MTMigration migrateToVersion:@"0.9" block:^{
        [expectingBlock3Run fulfill];
	}];
    
    XCTestExpectation *expectingBlock4Run = [self expectationWithDescription:@"Expecting block to be run AGAIN for version 1.0"];
	[MTMigration migrateToVersion:@"1.0" block:^{
        [expectingBlock4Run fulfill];
	}];
    
    [self waitForAllExpectations];
}

- (void)testMigratesOnFirstRun {

    [self setMainBundleAppVersion:@"1.0"];

    XCTestExpectation *expectationBlockRun = [self expectationWithDescription:@"Should execute migration after reset"];
	[MTMigration migrateToVersion:@"1.0" block:^{
        [expectationBlockRun fulfill];
	}];
	
    [self waitForAllExpectations];
}

- (void)testMigratesOnce {

    [self setMainBundleAppVersion:@"1.0"];

    XCTestExpectation *expectationBlockRun = [self expectationWithDescription:@"Expecting block to be run"];
	[MTMigration migrateToVersion:@"1.0" block:^{
        [expectationBlockRun fulfill];
	}];
	
	[MTMigration migrateToVersion:@"1.0" block:^{
        XCTFail(@"Should not execute a block for the same version twice.");
	}];
	
    [self waitForAllExpectations];
}

- (void)testMigrateToVersionWontRunForLowerAppVersions {
    
    [self setMainBundleAppVersion:@"0.1"];
    [MTMigration migrateToVersion:@"1.0" block:^{
        XCTFail(@"Should not execute a block for the same version twice.");
    }];
}

- (void)testMigratesPreviousBlocks {

    [self setMainBundleAppVersion:@"1.0"];

    XCTestExpectation *expectingBlock1Run = [self expectationWithDescription:@"Expecting block to be run for version 0.9"];
	[MTMigration migrateToVersion:@"0.9" block:^{
        [expectingBlock1Run fulfill];
	}];
	
    XCTestExpectation *expectingBlock2Run = [self expectationWithDescription:@"Expecting block to be run for version 1.0"];
	[MTMigration migrateToVersion:@"1.0" block:^{
        [expectingBlock2Run fulfill];
	}];
	
    [self waitForAllExpectations];
}

- (void)testMigratesInNaturalSortOrder
{

    [self setMainBundleAppVersion:@"1.0"];
    
    XCTestExpectation *expectingBlock1Run = [self expectationWithDescription:@"Expecting block to be run for version 0.9"];
	[MTMigration migrateToVersion:@"0.9" block:^{
        [expectingBlock1Run fulfill];
	}];
    
    [MTMigration migrateToVersion:@"0.1" block:^{
        XCTFail(@"Should use natural sort order, e.g. treat 0.10 as a follower of 0.9");
    }];
	
    XCTestExpectation *expectingBlock2Run = [self expectationWithDescription:@"Expecting block to be run for version 0.10"];
	[MTMigration migrateToVersion:@"0.10" block:^{
        [expectingBlock2Run fulfill];
	}];
	
    [self waitForAllExpectations];
}

#pragma mark - Test applicationUpdateBlock

- (void)testRunsApplicationUpdateBlockOnce {

    [self setMainBundleAppVersion:@"1.0"];
    
    XCTestExpectation *expectationBlockRun = [self expectationWithDescription:@"Should only call block once"];
    [MTMigration applicationUpdateBlock:^{
        [expectationBlockRun fulfill];
    }];
    
    [MTMigration applicationUpdateBlock:^{
        XCTFail(@"Expected applicationUpdateBlock to be called only once");
    }];
    
    [self waitForAllExpectations];
}

- (void)testRunsApplicationUpdateBlockeOnlyOnceWithMultipleMigrations {

    [self setMainBundleAppVersion:@"1.0"];
    
    [MTMigration migrateToVersion:@"0.8" block:^{
		// Do something
	}];
	
	[MTMigration migrateToVersion:@"0.9" block:^{
		// Do something
	}];
	
	[MTMigration migrateToVersion:@"0.10" block:^{
		// Do something
	}];
    
    XCTestExpectation *expectationBlockRun = [self expectationWithDescription:@"Should call the applicationUpdateBlock only once no matter how many migrations have to be done"];
    [MTMigration applicationUpdateBlock:^{
        [expectationBlockRun fulfill];
    }];

    [self waitForAllExpectations];
}

- (void)testRunsApplicationBlockButIgnoresFirstTimeInstall {
    
    [self setMainBundleAppVersion:@"1.0"];

    [MTMigration applicationUpdateBlock:^{
        XCTFail(@"Expected on first install, this block will never run.");
    } ignoreFirstInstall:YES];

    [self setMainBundleAppVersion:@"1.1"];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Expect block to be run"];
    [MTMigration applicationUpdateBlock:^{
        [expectation fulfill];
    } ignoreFirstInstall:YES];
    
    [self waitForAllExpectations];
}

- (void)waitForAllExpectations {
    
    [self waitForExpectationsWithTimeout:kDefaultWaitForExpectionsTimeout handler:^(NSError *error) {
        //do nothing
    }];
}

#pragma mark - Methods used to mock [NSBundle mainBundle] values
static NSString *mockAppVersion;
static NSString *mockAppBuild;

- (void)setMainBundleAppVersion:(NSString *)appVersion {
    mockAppVersion = appVersion;
}

- (void)setMainBundleAppBuild:(NSString *)appBuild {
    mockAppBuild = appBuild;
}

// The following methods use a technique called method swizzling (http://nshipster.com/method-swizzling/) and
// provide the only way in which the tests can manipulate the application version and build number in our static class
//
// In summary, the method `objectForInfoDictionaryKey` is swapped with this class's method `swizzled_objectForInfoDictionaryKey`
// allowing the test method to intercept this method call and provide appropriate mock responses.

- (void)swapOutBundleMethods {
    
    method_exchangeImplementations(class_getInstanceMethod([NSBundle class], @selector(objectForInfoDictionaryKey:)),
                                   class_getInstanceMethod([MTMigrationTests class], @selector(swizzled_objectForInfoDictionaryKey:)));
}

- (void)swapInBundleMethods {
    
    method_exchangeImplementations(class_getInstanceMethod([MTMigrationTests class], @selector(swizzled_objectForInfoDictionaryKey:)),
                                   class_getInstanceMethod([NSBundle class], @selector(objectForInfoDictionaryKey:)));
}

- (id)swizzled_objectForInfoDictionaryKey:(NSString *)key {
    
    if ([key isEqualToString:kBundleVersionKey] && mockAppBuild) {
        
        return mockAppBuild;
        
    } else if ([key isEqualToString:kBundleShortVersionStringKey] && mockAppVersion) {
        
        return mockAppVersion;
        
    } else {
        
        XCTFail(@"Mock bundle is missing a mock key/value pair");
    }
    
    return nil;
}

@end

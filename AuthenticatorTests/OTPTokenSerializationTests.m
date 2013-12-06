//
//  OTPTokenSerializationTests.m
//  Authenticator
//
//  Copyright (c) 2013 Matt Rubin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
//  the Software, and to permit persons to whom the Software is furnished to do so,
//  subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
//  FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
//  COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
//  IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

@import XCTest;
#import "OTPToken+Serialization.h"
#import "NSDictionary+QueryString.h"
#import "NSData+Base32.h"


static NSString * const kOTPScheme = @"otpauth";
static NSString * const kOTPTokenTypeCounterHost = @"hotp";
static NSString * const kOTPTokenTypeTimerHost   = @"totp";
static NSString * const kRandomKey = @"RANDOM";

static NSArray *typeNumbers;
static NSArray *names;
static NSArray *secretStrings;
static NSArray *algorithmNumbers;
static NSArray *digitNumbers;
static NSArray *periodNumbers;
static NSArray *counterNumbers;

static const unsigned char kValidSecret[] = { 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
                                              0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f };


@interface OTPTokenSerializationTests : XCTestCase

@end


@implementation OTPTokenSerializationTests

+ (void)setUp
{
    [super setUp];

    typeNumbers = @[@(OTPTokenTypeCounter), @(OTPTokenTypeTimer)];
    names = @[@"", @"Login", @"user123@website.com", @"Léon", @":/?#[]@!$&'()*+,;=%\"", [NSNull null]];
    secretStrings = @[@"12345678901234567890", @"12345678901234567890123456789012",
                      @"1234567890123456789012345678901234567890123456789012345678901234", @""];
    algorithmNumbers = @[@(OTPAlgorithmMD5), @(OTPAlgorithmSHA1), @(OTPAlgorithmSHA256), @(OTPAlgorithmSHA512)];
    digitNumbers = @[@6, @7, @8];
    periodNumbers = @[@0, @1, @([OTPToken defaultPeriod]), kRandomKey];
    counterNumbers = @[@0, @1, @([OTPToken defaultInitialCounter]), kRandomKey];
}

#pragma mark - Brute Force Tests

- (void)testDeserialization
{
    for (NSNumber *typeNumber in typeNumbers) {
        for (NSString *name in names) {
            for (NSString *secretString in secretStrings) {
                for (NSNumber *algorithmNumber in algorithmNumbers) {
                    for (NSNumber *digitNumber in digitNumbers) {
                        for (NSNumber *periodNumber in periodNumbers) {
                            for (NSNumber *counterNumber in counterNumbers) {
                                // Construct the URL
                                NSMutableDictionary *query = [NSMutableDictionary dictionary];
                                query[@"algorithm"] = [NSString stringForAlgorithm:[algorithmNumber unsignedIntValue]];
                                query[@"digits"] = digitNumber;
                                query[@"secret"] = [[[secretString dataUsingEncoding:NSASCIIStringEncoding] base32String] stringByReplacingOccurrencesOfString:@"=" withString:@""];
                                query[@"period"] = [periodNumber isEqual:kRandomKey] ? @(arc4random()%299 + 1) : periodNumber;
                                query[@"counter"] = [counterNumber isEqual:kRandomKey] ? @(arc4random() + ((uint64_t)arc4random() << 32)) : counterNumber;

                                NSURLComponents *urlComponents = [NSURLComponents new];
                                urlComponents.scheme = kOTPScheme;
                                urlComponents.host = [NSString stringForTokenType:[typeNumber unsignedIntegerValue]];
                                if (![name isEqual:[NSNull null]])
                                    urlComponents.path = [@"/" stringByAppendingString:name];
                                urlComponents.query = [query queryString];

                                // Create the token
                                OTPToken *token = [OTPToken tokenWithURL:[urlComponents URL]];

                                // Note: [OTPToken tokenWithURL:] will return nil if the token described by the URL is invalid.
                                if (token) {
                                    XCTAssertEqual(token.type, [typeNumber unsignedIntegerValue], @"Incorrect token type");
                                    XCTAssertEqualObjects(token.name, ([name isEqual:[NSNull null]] || [name isEqualToString:@""]) ? nil : name, @"Incorrect token name");
                                    XCTAssertEqualObjects(token.secret, [secretString dataUsingEncoding:NSASCIIStringEncoding], @"Incorrect token secret");
                                    XCTAssertEqual(token.algorithm, [algorithmNumber unsignedIntValue], @"Incorrect token algorithm");
                                    XCTAssertEqual(token.digits, [digitNumber unsignedIntegerValue], @"Incorrect token digits");
                                    XCTAssertEqual(token.period, [query[@"period"] doubleValue], @"Incorrect token period");
                                    XCTAssertEqual(token.counter, [query[@"counter"] unsignedLongLongValue], @"Incorrect token counter");
                                } else {
                                    // If nil was returned from [OTPToken tokenWithURL:], create the same token manually and ensure it's invalid
                                    OTPToken *invalidToken = [OTPToken new];
                                    invalidToken.type = [typeNumber unsignedIntegerValue];
                                    invalidToken.name = name;
                                    invalidToken.secret = [secretString dataUsingEncoding:NSASCIIStringEncoding];
                                    invalidToken.algorithm = [algorithmNumber unsignedIntValue];
                                    invalidToken.digits = [digitNumber unsignedIntegerValue];
                                    invalidToken.period = [query[@"period"] doubleValue];
                                    invalidToken.counter = [query[@"counter"] unsignedLongLongValue];

                                    XCTAssertFalse([invalidToken validate], @"The token should be invalid");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

- (void)testTokenWithURLAndSecret
{
    for (NSNumber *typeNumber in typeNumbers) {
        for (NSString *name in names) {
            for (NSString *secretString in secretStrings) {
                for (NSNumber *algorithmNumber in algorithmNumbers) {
                    for (NSNumber *digitNumber in digitNumbers) {
                        for (NSNumber *periodNumber in periodNumbers) {
                            for (NSNumber *counterNumber in counterNumbers) {
                                for (NSString *secondSecretString in secretStrings) {
                                    // Construct the URL
                                    NSMutableDictionary *query = [NSMutableDictionary dictionary];
                                    query[@"algorithm"] = [NSString stringForAlgorithm:[algorithmNumber unsignedIntValue]];
                                    query[@"digits"] = digitNumber;
                                    query[@"secret"] = [[[secretString dataUsingEncoding:NSASCIIStringEncoding] base32String] stringByReplacingOccurrencesOfString:@"=" withString:@""];
                                    query[@"period"] = [periodNumber isEqual:kRandomKey] ? @(arc4random()%299 + 1) : periodNumber;
                                    query[@"counter"] = [counterNumber isEqual:kRandomKey] ? @(arc4random() + ((uint64_t)arc4random() << 32)) : counterNumber;

                                    NSURLComponents *urlComponents = [NSURLComponents new];
                                    urlComponents.scheme = kOTPScheme;
                                    urlComponents.host = [NSString stringForTokenType:[typeNumber unsignedIntegerValue]];
                                    if (![name isEqual:[NSNull null]])
                                        urlComponents.path = [@"/" stringByAppendingString:name];
                                    urlComponents.query = [query queryString];

                                    // Create the token
                                    NSData *secret = [secondSecretString dataUsingEncoding:NSASCIIStringEncoding];
                                    OTPToken *token = [OTPToken tokenWithURL:[urlComponents URL] secret:secret];

                                    // Note: [OTPToken tokenWithURL:] will return nil if the token described by the URL is invalid.
                                    if (token) {
                                        XCTAssertEqual(token.type, [typeNumber unsignedIntegerValue], @"Incorrect token type");
                                        XCTAssertEqualObjects(token.name, ([name isEqual:[NSNull null]] || [name isEqualToString:@""]) ? nil : name, @"Incorrect token name");
                                        XCTAssertEqualObjects(token.secret, secret, @"Incorrect token secret");
                                        XCTAssertEqual(token.algorithm, [algorithmNumber unsignedIntValue], @"Incorrect token algorithm");
                                        XCTAssertEqual(token.digits, [digitNumber unsignedIntegerValue], @"Incorrect token digits");
                                        XCTAssertEqual(token.period, [query[@"period"] doubleValue], @"Incorrect token period");
                                        XCTAssertEqual(token.counter, [query[@"counter"] unsignedLongLongValue], @"Incorrect token counter");
                                    } else {
                                        // If nil was returned from [OTPToken tokenWithURL:], create the same token manually and ensure it's invalid
                                        OTPToken *invalidToken = [OTPToken new];
                                        invalidToken.type = [typeNumber unsignedIntegerValue];
                                        invalidToken.name = name;
                                        invalidToken.secret = secret;
                                        invalidToken.algorithm = [algorithmNumber unsignedIntValue];
                                        invalidToken.digits = [digitNumber unsignedIntegerValue];
                                        invalidToken.period = [query[@"period"] doubleValue];
                                        invalidToken.counter = [query[@"counter"] unsignedLongLongValue];

                                        XCTAssertFalse([invalidToken validate], @"The token should be invalid");
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

- (void)testSerialization
{
    for (NSNumber *typeNumber in typeNumbers) {
        for (NSString *nameValue in names) {
            for (NSString *secretString in secretStrings) {
                for (NSNumber *algorithmNumber in algorithmNumbers) {
                    for (NSNumber *digitNumber in digitNumbers) {
                        for (NSNumber *periodNumber in periodNumbers) {
                            for (NSNumber *counterNumber in counterNumbers) {

                                NSTimeInterval period;
                                if ([periodNumber isEqual:kRandomKey]) {
                                    period = arc4random();
                                } else {
                                    period = [periodNumber doubleValue];
                                }

                                uint64_t counter;
                                if ([counterNumber isEqual:kRandomKey]) {
                                    counter = arc4random() + ((uint64_t)arc4random() << 32);
                                } else {
                                    counter = [counterNumber unsignedLongLongValue];
                                }

                                NSString *name;
                                if ([nameValue isEqual:[NSNull null]]) {
                                    name = nil;
                                } else {
                                    name = nameValue;
                                }

                                // Create the token
                                OTPToken *token = [OTPToken new];
                                token.type = [typeNumber unsignedIntegerValue];
                                token.name = name;
                                token.secret = [secretString dataUsingEncoding:NSASCIIStringEncoding];
                                token.algorithm = [algorithmNumber unsignedIntValue];
                                token.digits = [digitNumber unsignedIntegerValue];
                                token.period = period;
                                token.counter = counter;

                                // Serialize
                                NSURL *url = token.url;

                                // Test scheme
                                XCTAssertEqualObjects(url.scheme, kOTPScheme,
                                                      @"The url scheme should be \"%@\"", kOTPScheme);
                                // Test type
                                NSString *expectedHost = [typeNumber unsignedIntegerValue] == OTPTokenTypeCounter ? kOTPTokenTypeCounterHost : kOTPTokenTypeTimerHost;
                                XCTAssertEqualObjects(url.host, expectedHost,
                                                      @"The url host should be \"%@\"", expectedHost);
                                // Test name
                                if (name) {
                                    XCTAssertEqualObjects([url.path substringFromIndex:1] , name,
                                                          @"The url path should be \"%@\"", name);
                                } else {
                                    XCTAssertEqualObjects(url.path, @"", @"The url path should be empty");
                                }

                                NSDictionary *queryArguments = [NSDictionary dictionaryWithQueryString:url.query];

                                // Test algorithm
                                NSString *expectedAlgorithmString = [NSString stringForAlgorithm:[algorithmNumber unsignedIntValue]];
                                XCTAssertEqualObjects(queryArguments[@"algorithm"], expectedAlgorithmString,
                                                      @"The algorithm value should be \"%@\"", expectedAlgorithmString);
                                // Test digits
                                NSString *expectedDigitsString = [digitNumber stringValue];
                                XCTAssertEqualObjects(queryArguments[@"digits"], expectedDigitsString,
                                                      @"The digits value should be \"%@\"", expectedDigitsString);
                                // Test secret
                                XCTAssertNil(queryArguments[@"secret"], @"The url query string should not contain the secret");

                                // Test period
                                if ([typeNumber unsignedIntegerValue] == OTPTokenTypeTimer) {
                                    NSString *expectedPeriodString = [@(period) stringValue];
                                    XCTAssertEqualObjects(queryArguments[@"period"], expectedPeriodString,
                                                          @"The period value should be \"%@\"", expectedPeriodString);
                                } else {
                                    XCTAssertNil(queryArguments[@"period"], @"The url query string should not contain the period");
                                }
                                // Test counter
                                if ([typeNumber unsignedIntegerValue] == OTPTokenTypeCounter) {
                                    NSString *expectedCounterString = [@(counter) stringValue];
                                    XCTAssertEqualObjects(queryArguments[@"counter"], expectedCounterString,
                                                          @"The counter value should be \"%@\"", expectedCounterString);
                                } else {
                                    XCTAssertNil(queryArguments[@"counter"], @"The url query string should not contain the counter");
                                }

                                XCTAssertEqual(queryArguments.count, (NSUInteger)3, @"There shouldn't be any unexpected query arguments");

                                // Check url again
                                NSURL *checkURL = token.url;
                                XCTAssertEqualObjects(url, checkURL, @"Repeated calls to -url should return the same result!");
                            }
                        }
                    }
                }
            }
        }
    }
}


#pragma mark - Test with specific URLs
// From Google Authenticator for iOS
// https://code.google.com/p/google-authenticator/source/browse/mobile/ios/Classes/OTPAuthURLTest.m

#pragma mark Deserialization

- (void)testTokenWithTOTPURL
{
    NSData *secret = [NSData dataWithBytes:kValidSecret length:sizeof(kValidSecret)];
    OTPToken *token = [OTPToken tokenWithURL:[NSURL URLWithString:@"otpauth://totp/L%C3%A9on?algorithm=SHA256&digits=8&period=45&secret=AAAQEAYEAUDAOCAJBIFQYDIOB4"]];

    XCTAssertEqualObjects(token.name, @"Léon");
    XCTAssertEqualObjects(token.secret, secret);
    XCTAssertEqual(token.type, OTPTokenTypeTimer);
    XCTAssertEqual(token.algorithm, OTPAlgorithmSHA256);
    XCTAssertEqual(token.period, 45.0);
    XCTAssertEqual(token.digits, 8U);
}

- (void)testTokenWithHOTPURL
{
    NSData *secret = [NSData dataWithBytes:kValidSecret length:sizeof(kValidSecret)];
    OTPToken *token = [OTPToken tokenWithURL:[NSURL URLWithString:@"otpauth://hotp/L%C3%A9on?algorithm=SHA256&digits=8&counter=18446744073709551615&secret=AAAQEAYEAUDAOCAJBIFQYDIOB4"]];

    XCTAssertEqualObjects(token.name, @"Léon");
    XCTAssertEqualObjects(token.secret, secret);
    XCTAssertEqual(token.type, OTPTokenTypeCounter);
    XCTAssertEqual(token.algorithm, OTPAlgorithmSHA256);
    XCTAssertEqual(token.counter, 18446744073709551615ULL);
    XCTAssertEqual(token.digits, 8U);
}

- (void)testTokenWithInvalidURLs
{
    NSArray *badURLs = @[@"http://foo", // invalid scheme
                         @"otpauth://foo", // invalid type
                         @"otpauth://totp/bar", // missing secret
                         @"otpauth://totp/bar?secret=AAAQEAYEAUDAOCAJBIFQYDIOB4&period=0", // invalid period
                         @"otpauth://totp/bar?secret=AAAQEAYEAUDAOCAJBIFQYDIOB4&algorithm=RC4", // invalid algorithm
                         @"otpauth://totp/bar?secret=AAAQEAYEAUDAOCAJBIFQYDIOB4&digits=2", // invalid digits
                         ];

    for (NSString *badURL in badURLs) {
        OTPToken *token = [OTPToken tokenWithURL:[NSURL URLWithString:badURL]];
        XCTAssertNil(token, @"Invalid url (%@) generated %@", badURL, token);
    }
}

#pragma mark Serialization

- (void)testTOTPURL
{
    OTPToken *token = [OTPToken tokenWithURL:[NSURL URLWithString:@"otpauth://totp/L%C3%A9on?algorithm=SHA256&digits=8&period=45&secret=AAAQEAYEAUDAOCAJBIFQYDIOB4"]];
    NSURL *url = token.url;

    XCTAssertEqualObjects(url.scheme, @"otpauth");
    XCTAssertEqualObjects(url.host, @"totp");
    XCTAssertEqualObjects([url.path substringFromIndex:1], @"Léon");

    NSDictionary *expectedQueryString = @{@"algorithm": @"SHA256",
                                          @"digits": @"8",
                                          @"period": @"45"};
    XCTAssertEqualObjects([NSDictionary dictionaryWithQueryString:url.query], expectedQueryString);
}

- (void)testHOTPURL
{
    OTPToken *token = [OTPToken tokenWithURL:[NSURL URLWithString:@"otpauth://hotp/L%C3%A9on?algorithm=SHA256&digits=8&counter=18446744073709551615&secret=AAAQEAYEAUDAOCAJBIFQYDIOB4"]];
    NSURL *url = token.url;

    XCTAssertEqualObjects(url.scheme, @"otpauth");
    XCTAssertEqualObjects(url.host, @"hotp");
    XCTAssertEqualObjects([url.path substringFromIndex:1], @"Léon");

    NSDictionary *expectedQueryString = @{@"algorithm": @"SHA256",
                                          @"digits": @"8",
                                          @"counter": @"18446744073709551615"};
    XCTAssertEqualObjects([NSDictionary dictionaryWithQueryString:url.query], expectedQueryString);
}

@end

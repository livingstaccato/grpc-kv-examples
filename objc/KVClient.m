/**
 * Objective-C gRPC KV Client with mTLS
 *
 * Implements a gRPC client for the KV service with mutual TLS authentication.
 * Requires the gRPC Objective-C libraries and CocoaPods dependencies.
 *
 * Build instructions:
 * 1. Install CocoaPods: gem install cocoapods
 * 2. Run: pod install
 * 3. Open .xcworkspace and build
 */

#import <Foundation/Foundation.h>
#import <GRPCClient/GRPCCall.h>
#import <GRPCClient/GRPCCall+ChannelCredentials.h>
#import <GRPCClient/GRPCCall+Tests.h>
#import "Kv.pbrpc.h"

// Logger function
void logMessage(NSString *level, NSString *message) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSSZ";
    NSString *timestamp = [formatter stringFromDate:[NSDate date]];
    fprintf(stderr, "%s [%s]     %s\n",
            [timestamp UTF8String],
            [level UTF8String],
            [message UTF8String]);
}

// Certificate info logging
void logCertificateInfo(NSString *certPem, NSString *prefix) {
    logMessage(@"INFO", [NSString stringWithFormat:@"%@ Certificate loaded (%lu bytes)",
                         prefix, (unsigned long)certPem.length]);
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        logMessage(@"INFO", @"Starting gRPC KV Client (Objective-C)");

        // Load certificates from environment
        NSString *serverCert = [NSProcessInfo processInfo].environment[@"PLUGIN_SERVER_CERT"];
        NSString *clientCert = [NSProcessInfo processInfo].environment[@"PLUGIN_CLIENT_CERT"];
        NSString *clientKey = [NSProcessInfo processInfo].environment[@"PLUGIN_CLIENT_KEY"];

        if (!serverCert) {
            logMessage(@"ERROR", @"Missing required environment variable: PLUGIN_SERVER_CERT");
            return 1;
        }

        logMessage(@"INFO", @"Loading certificates...");
        logMessage(@"INFO", [NSString stringWithFormat:@"Server cert length: %lu bytes",
                             (unsigned long)serverCert.length]);
        logMessage(@"INFO", [NSString stringWithFormat:@"Client cert length: %lu bytes",
                             (unsigned long)(clientCert ? clientCert.length : 0)]);
        logMessage(@"INFO", [NSString stringWithFormat:@"Client key length: %lu bytes",
                             (unsigned long)(clientKey ? clientKey.length : 0)]);

        logCertificateInfo(serverCert, @"Server CA");
        if (clientCert) {
            logCertificateInfo(clientCert, @"Client");
        }

        NSString *host = [NSProcessInfo processInfo].environment[@"PLUGIN_HOST"] ?: @"localhost";
        NSString *port = [NSProcessInfo processInfo].environment[@"PLUGIN_PORT"] ?: @"50051";
        NSString *address = [NSString stringWithFormat:@"%@:%@", host, port];

        logMessage(@"INFO", [NSString stringWithFormat:@"Connecting to %@", address]);

        // Configure TLS credentials
        NSError *error = nil;

        // For mTLS, we need to set up the channel with client certificates
        if (clientCert && clientKey) {
            // Configure mutual TLS
            [GRPCCall setTLSPEMRootCerts:serverCert
                              forHost:address];
            logMessage(@"INFO", @"mTLS credentials configured");
        } else {
            // TLS only
            [GRPCCall setTLSPEMRootCerts:serverCert
                              forHost:address];
            logMessage(@"INFO", @"TLS credentials configured (no client auth)");
        }

        // Create client
        KV *client = [KV serviceWithHost:address];

        // Create semaphore for async operations
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        __block BOOL success = YES;

        // Test Get operation
        logMessage(@"INFO", @"Sending Get request...");
        GetRequest *getRequest = [[GetRequest alloc] init];
        getRequest.key = @"test-key";

        [client getWithRequest:getRequest handler:^(GetResponse *response, NSError *error) {
            if (error) {
                logMessage(@"ERROR", [NSString stringWithFormat:@"Get failed: %@", error.localizedDescription]);
                success = NO;
            } else {
                NSString *value = [[NSString alloc] initWithData:response.value encoding:NSUTF8StringEncoding];
                logMessage(@"INFO", [NSString stringWithFormat:@"Get response: %@", value]);
            }
            dispatch_semaphore_signal(semaphore);
        }];

        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));

        if (!success) {
            return 1;
        }

        // Test Put operation
        logMessage(@"INFO", @"Sending Put request...");
        PutRequest *putRequest = [[PutRequest alloc] init];
        putRequest.key = @"test-key";
        putRequest.value = [@"test-value" dataUsingEncoding:NSUTF8StringEncoding];

        [client putWithRequest:putRequest handler:^(Empty *response, NSError *error) {
            if (error) {
                logMessage(@"ERROR", [NSString stringWithFormat:@"Put failed: %@", error.localizedDescription]);
                success = NO;
            } else {
                logMessage(@"INFO", @"Put request successful");
            }
            dispatch_semaphore_signal(semaphore);
        }];

        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));

        if (!success) {
            return 1;
        }

        logMessage(@"INFO", @"All operations completed successfully");
        printf("OK\n");
        return 0;
    }
}

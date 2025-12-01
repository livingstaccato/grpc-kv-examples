/**
 * Objective-C gRPC KV Server with mTLS
 *
 * NOTE: gRPC Objective-C is primarily designed for client-side usage (iOS/macOS apps).
 * For server-side functionality, consider using:
 * - Swift with grpc-swift (NIO-based)
 * - C++ gRPC server with Objective-C++ bridging
 *
 * This file provides a reference implementation structure.
 */

#import <Foundation/Foundation.h>

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

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        logMessage(@"INFO", @"Objective-C gRPC KV Server");
        logMessage(@"INFO", @"NOTE: gRPC Objective-C is primarily client-side focused");

        // Load certificates from environment
        NSString *serverCert = [NSProcessInfo processInfo].environment[@"PLUGIN_SERVER_CERT"];
        NSString *serverKey = [NSProcessInfo processInfo].environment[@"PLUGIN_SERVER_KEY"];
        NSString *clientCert = [NSProcessInfo processInfo].environment[@"PLUGIN_CLIENT_CERT"];

        if (!serverCert || !serverKey) {
            logMessage(@"ERROR", @"Missing required environment variables: PLUGIN_SERVER_CERT, PLUGIN_SERVER_KEY");
            return 1;
        }

        logMessage(@"INFO", @"Certificate configuration:");
        logMessage(@"INFO", [NSString stringWithFormat:@"  Server cert length: %lu bytes",
                             (unsigned long)serverCert.length]);
        logMessage(@"INFO", [NSString stringWithFormat:@"  Server key length: %lu bytes",
                             (unsigned long)serverKey.length]);
        logMessage(@"INFO", [NSString stringWithFormat:@"  Client cert length: %lu bytes",
                             (unsigned long)(clientCert ? clientCert.length : 0)]);

        NSString *port = [NSProcessInfo processInfo].environment[@"PLUGIN_PORT"] ?: @"50051";
        logMessage(@"INFO", [NSString stringWithFormat:@"Server would listen on 0.0.0.0:%@", port]);

        printf("\n");
        printf("=== Objective-C gRPC Server Implementation Note ===\n");
        printf("The gRPC Objective-C library is designed for client-side use.\n");
        printf("For server-side gRPC in Objective-C environments:\n");
        printf("  1. Use Swift with grpc-swift (https://github.com/grpc/grpc-swift)\n");
        printf("  2. Use C++ gRPC with Objective-C++ bridging\n");
        printf("  3. Use a separate server process with IPC\n");
        printf("\n");
        printf("The client implementation (KVClient.m) is the recommended approach.\n");
        printf("==================================================\n");

        return 0;
    }
}

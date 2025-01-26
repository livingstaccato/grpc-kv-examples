package main

import (
    "log"
    "os"
    "time"
    "net"
    "fmt"
    "strings"

    "context"
    "crypto/tls"
    "crypto/x509"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials"
    "google.golang.org/grpc/keepalive"
    "google.golang.org/grpc/peer"
    "google.golang.org/grpc/codes"
    "google.golang.org/grpc/status"
    "google.golang.org/grpc/metadata"

    "github.com/livingstaccato/grpc-kv-examples/proto"
)

type server struct {
    proto.UnimplementedKVServer
    logger *log.Logger
}

// logCertificateDetails logs detailed information about an X.509 certificate
func logCertificateDetails(logger *log.Logger, cert *x509.Certificate, prefix string) {
    logger.Printf("🔍 📜 %s Certificate Details:", prefix)
    logger.Printf("🔍 📋 Subject: %s", cert.Subject.String())
    logger.Printf("🔍 📋 Issuer: %s", cert.Issuer.String())
    logger.Printf("🔍 ⏰ Valid From: %s", cert.NotBefore)
    logger.Printf("🔍 ⏰ Valid Until: %s", cert.NotAfter)
    logger.Printf("🔍 🔢 Serial Number: %s", cert.SerialNumber)
    logger.Printf("🔍 📊 Version: %d", cert.Version)

    // Log key usage
    if cert.KeyUsage != 0 {
        var usages []string
        if (cert.KeyUsage & x509.KeyUsageDigitalSignature) != 0 { usages = append(usages, "DigitalSignature") }
        if (cert.KeyUsage & x509.KeyUsageContentCommitment) != 0 { usages = append(usages, "ContentCommitment") }
        if (cert.KeyUsage & x509.KeyUsageKeyEncipherment) != 0 { usages = append(usages, "KeyEncipherment") }
        if (cert.KeyUsage & x509.KeyUsageDataEncipherment) != 0 { usages = append(usages, "DataEncipherment") }
        if (cert.KeyUsage & x509.KeyUsageKeyAgreement) != 0 { usages = append(usages, "KeyAgreement") }
        if (cert.KeyUsage & x509.KeyUsageCertSign) != 0 { usages = append(usages, "CertSign") }
        if (cert.KeyUsage & x509.KeyUsageCRLSign) != 0 { usages = append(usages, "CRLSign") }
        logger.Printf("🔍 🔑 Key Usage: %s", strings.Join(usages, ", "))
    }

    // Log extended key usage
    if len(cert.ExtKeyUsage) > 0 {
        var usages []string
        for _, usage := range cert.ExtKeyUsage {
            switch usage {
            case x509.ExtKeyUsageServerAuth:
                usages = append(usages, "ServerAuth")
            case x509.ExtKeyUsageClientAuth:
                usages = append(usages, "ClientAuth")
            case x509.ExtKeyUsageCodeSigning:
                usages = append(usages, "CodeSigning")
            case x509.ExtKeyUsageEmailProtection:
                usages = append(usages, "EmailProtection")
            case x509.ExtKeyUsageTimeStamping:
                usages = append(usages, "TimeStamping")
            }
        }
        logger.Printf("🔍 🔐 Extended Key Usage: %s", strings.Join(usages, ", "))
    }

    // Log DNS names and IP addresses
    if len(cert.DNSNames) > 0 {
        logger.Printf("🔍 🌐 DNS Names: %s", strings.Join(cert.DNSNames, ", "))
    }
    if len(cert.IPAddresses) > 0 {
        var ips []string
        for _, ip := range cert.IPAddresses {
            ips = append(ips, ip.String())
        }
        logger.Printf("🔍 🌐 IP Addresses: %s", strings.Join(ips, ", "))
    }

    // Log basic constraints
    if cert.BasicConstraintsValid {
        logger.Printf("🔍 📏 Basic Constraints - Is CA: %t, Max Path Length: %d", 
            cert.IsCA, cert.MaxPathLen)
    }
}

func (s *server) logClientConnection(ctx context.Context) {
    if p, ok := peer.FromContext(ctx); ok {
        s.logger.Printf("🔌 🌐 New connection from: %v", p.Addr)
        if mtls, ok := p.AuthInfo.(credentials.TLSInfo); ok {
            s.logger.Printf("🔒 🔐 TLS version: 0x%x", mtls.State.Version)
            s.logger.Printf("🔒 🔑 Cipher suite: 0x%x", mtls.State.CipherSuite)
            
            // Log all certificates in the chain
            for i, cert := range mtls.State.PeerCertificates {
                logCertificateDetails(s.logger, cert, fmt.Sprintf("Client Chain Certificate %d", i+1))
            }
        }
    }

    // Log request metadata
    if md, ok := metadata.FromIncomingContext(ctx); ok {
        s.logger.Printf("📝 📋 Request Metadata:")
        for key, values := range md {
            s.logger.Printf("📝 🏷️ %s: %v", key, values)
        }
    }
}

func (s *server) Put(ctx context.Context, req *proto.PutRequest) (*proto.Empty, error) {
    s.logger.Printf("📥 💾 Received Put request - Key: %s", req.Key)
    s.logClientConnection(ctx)

    // Add request validation
    if req.Key == "" {
        s.logger.Printf("❌ 🚫 Put request rejected: empty key")
        return nil, status.Error(codes.InvalidArgument, "key cannot be empty")
    }
    if len(req.Value) == 0 {
        s.logger.Printf("❌ 🚫 Put request rejected: empty value")
        return nil, status.Error(codes.InvalidArgument, "value cannot be empty")
    }

    s.logger.Printf("✅ 💾 Put request completed successfully")
    return &proto.Empty{}, nil
}

func (s *server) Get(ctx context.Context, req *proto.GetRequest) (*proto.GetResponse, error) {
    s.logger.Printf("📥 🔍 Received Get request - Key: %s", req.Key)
    s.logClientConnection(ctx)

    // Add request validation
    if req.Key == "" {
        s.logger.Printf("❌ 🚫 Get request rejected: empty key")
        return nil, status.Error(codes.InvalidArgument, "key cannot be empty")
    }

    s.logger.Printf("✅ 🔍 Get request completed successfully")
    return &proto.GetResponse{Value: []byte("OK")}, nil
}

func setupLogger() *log.Logger {
    return log.New(os.Stdout, "", log.LstdFlags|log.Lshortfile|log.Lmicroseconds)
}

func validateCertificates(logger *log.Logger, serverCertPEM, serverKeyPEM, clientCertPEM string) error {
    if serverCertPEM == "" || serverKeyPEM == "" {
        return fmt.Errorf("❌ 🔒 server certificate or key is missing")
    }

    // Parse and validate server certificate
    serverCert, err := tls.X509KeyPair([]byte(serverCertPEM), []byte(serverKeyPEM))
    if err != nil {
        logger.Printf("❌ 🔒 Failed to load server key pair: %v", err)
        return err
    }

    x509Cert, err := x509.ParseCertificate(serverCert.Certificate[0])
    if err != nil {
        logger.Printf("❌ 🔒 Failed to parse server certificate: %v", err)
        return err
    }

    // Validate certificate expiration
    now := time.Now()
    if now.Before(x509Cert.NotBefore) {
        logger.Printf("❌ ⏰ Server certificate is not yet valid")
        return fmt.Errorf("server certificate is not yet valid")
    }
    if now.After(x509Cert.NotAfter) {
        logger.Printf("❌ ⏰ Server certificate has expired")
        return fmt.Errorf("server certificate has expired")
    }

    return nil
}

func monitorConnections(s *grpc.Server, logger *log.Logger) {
    ticker := time.NewTicker(30 * time.Second)
    go func() {
        for range ticker.C {
            stats := s.GetServiceInfo()
            logger.Printf("📊 🔄 Server Stats - Number of services: %d", len(stats))
        }
    }()
}

func main() {
    logger := setupLogger()
    logger.Printf("🚀 🔄 Starting gRPC server...")
    
    // Load certificates from environment
    serverCertPEM := os.Getenv("PLUGIN_SERVER_CERT")
    serverKeyPEM := os.Getenv("PLUGIN_SERVER_KEY")
    clientCertPEM := os.Getenv("PLUGIN_CLIENT_CERT")

    // Validate certificates
    if err := validateCertificates(logger, serverCertPEM, serverKeyPEM, clientCertPEM); err != nil {
        logger.Fatalf("❌ 🔒 Certificate validation failed: %v", err)
    }

    // Create certificate pool
    certPool := x509.NewCertPool()
    logger.Printf("🔒 🔄 Creating certificate pool")

    if clientCertPEM != "" {
        if ok := certPool.AppendCertsFromPEM([]byte(clientCertPEM)); !ok {
            logger.Fatalf("❌ 🔒 Failed to append client certificate to pool")
        }
        logger.Printf("✅ 🔒 Added client certificate to pool")
    } else {
        if ok := certPool.AppendCertsFromPEM([]byte(serverCertPEM)); !ok {
            logger.Fatalf("❌ 🔒 Failed to append server certificate to pool")
        }
        logger.Printf("✅ 🔒 Added server certificate to pool (self-signed mode)")
    }

    // Parse server certificate for logging
    cert, err := tls.X509KeyPair([]byte(serverCertPEM), []byte(serverKeyPEM))
    if err != nil {
        logger.Fatalf("❌ 🔒 Failed to load server key pair: %v", err)
    }
    x509Cert, err := x509.ParseCertificate(cert.Certificate[0])
    if err != nil {
        logger.Fatalf("❌ 🔒 Failed to parse server certificate: %v", err)
    }
    logCertificateDetails(logger, x509Cert, "Server")

    // Configure TLS
    logger.Printf("🔒 ⚙️ Configuring TLS settings...")
    tlsConfig := &tls.Config{
        Certificates: []tls.Certificate{cert},
        ClientAuth:   tls.RequireAndVerifyClientCert,
        ClientCAs:    certPool,
        MinVersion:   tls.VersionTLS12,
        MaxVersion:   tls.VersionTLS13,
        CipherSuites: []uint16{
            tls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
            tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
            tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
            tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
            tls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,
            tls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
        },
        PreferServerCipherSuites: true,
    }

    // Configure keepalive parameters
    kaep := keepalive.EnforcementPolicy{
        MinTime:             5 * time.Second,
        PermitWithoutStream: true,
    }
    kasp := keepalive.ServerParameters{
        MaxConnectionIdle:     15 * time.Second,
        MaxConnectionAge:      30 * time.Second,
        MaxConnectionAgeGrace: 5 * time.Second,
        Time:                  5 * time.Second,
        Timeout:              1 * time.Second,
    }

    // Create listener
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        logger.Fatalf("❌ 🌐 Failed to listen: %v", err)
    }
    logger.Printf("✅ 🌐 Server listening on :50051")

    // Create gRPC server with credentials
    creds := credentials.NewTLS(tlsConfig)
    s := grpc.NewServer(
        grpc.Creds(creds),
        grpc.KeepaliveEnforcementPolicy(kaep),
        grpc.KeepaliveParams(kasp),
        grpc.UnaryInterceptor(func(ctx context.Context, req interface{}, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (interface{}, error) {
            start := time.Now()
            logger.Printf("📥 🕒 Starting %s", info.FullMethod)
            
            // Extract peer information for logging
            if p, ok := peer.FromContext(ctx); ok {
                logger.Printf("👤 🌐 Peer address: %v", p.Addr)
            }
            
            // Handle the request
            resp, err := handler(ctx, req)
            
            // Log the completion
            duration := time.Since(start)
            if err != nil {
                logger.Printf("❌ ⚡ %s failed after %v: %v", info.FullMethod, duration, err)
            } else {
                logger.Printf("✅ ⚡ %s completed in %v", info.FullMethod, duration)
            }
            
            return resp, err
        }),
    )

    // Register service
    proto.RegisterKVServer(s, &server{
        logger: logger,
    })

    // Start connection monitoring
    monitorConnections(s, logger)

    // Log server configuration
    logger.Printf("🔧 ⚙️ Server Configuration:")
    logger.Printf("🔒 🔐 TLS Version: %d-%d", tlsConfig.MinVersion, tlsConfig.MaxVersion)
    logger.Printf("🔒 🔑 Client Auth Mode: %v", tlsConfig.ClientAuth)
    logger.Printf("⏱️ 🔄 Keepalive: Time=%v, Timeout=%v", kasp.Time, kasp.Timeout)
    logger.Printf("⏱️ ⚡ Max Connection Age: %v", kasp.MaxConnectionAge)
    logger.Printf("📊 💻 Max Connection Idle: %v", kasp.MaxConnectionIdle)

    // Create a context for graceful shutdown
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    // Handle shutdown signals
    go func() {
        sigChan := make(chan os.Signal, 1)
        // signal.Notify(sigChan, os.Interrupt, syscall.SIGTERM)
        <-sigChan
        logger.Printf("👋 💤 Received shutdown signal")
        cancel()
        s.GracefulStop()
    }()

    // Start server
    logger.Printf("🚀 ✨ Starting gRPC server")
    if err := s.Serve(lis); err != nil {
        if ctx.Err() == context.Canceled {
            logger.Printf("👋 ✅ Server shutdown gracefully")
        } else {
            logger.Fatalf("❌ 💥 Failed to serve: %v", err)
        }
    }
}

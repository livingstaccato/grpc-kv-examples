package main

import (
    "log"
    "os"
    "time"
    "fmt"

    "context"
    "crypto/tls"
    "crypto/x509"
    "encoding/pem"
    "bytes"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials"
    "google.golang.org/grpc/keepalive"
    "google.golang.org/grpc/status"

    "github.com/livingstaccato/grpc-kv-examples/proto"
)

func logCertInfo(cert *x509.Certificate, prefix string) {
    log.Printf("🔍 %s Certificate Details: 📋", prefix)
    log.Printf("🔍  Subject: %s 📝", cert.Subject)
    log.Printf("🔍  Issuer: %s 📝", cert.Issuer)
    log.Printf("🔍  Valid From: %s ⏰", cert.NotBefore)
    log.Printf("🔍  Valid Until: %s ⏰", cert.NotAfter)
    log.Printf("🔍  Serial Number: %s 🔢", cert.SerialNumber)
    log.Printf("🔍  Version: %d 📊", cert.Version)
    log.Printf("🔍  Key Usage: %v 🔑", cert.KeyUsage)
    log.Printf("🔍  Extended Key Usage: %v 🔐", cert.ExtKeyUsage)
    if len(cert.DNSNames) > 0 {
        log.Printf("🔍  DNS Names: %v 🌐", cert.DNSNames)
    }
    if len(cert.IPAddresses) > 0 {
        log.Printf("🔍  IP Addresses: %v 🌐", cert.IPAddresses)
    }
}

func getTrustedServerCert(addr string) ([]byte, error) {
    log.Printf("🌐 Dialing server to fetch certificate 🔄")
    conn, err := tls.Dial("tcp", addr, &tls.Config{
        InsecureSkipVerify: true,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to dial server: %v", err)
    }
    defer conn.Close()

    log.Printf("🌐 Connection established, getting peer certificates 📜")
    certs := conn.ConnectionState().PeerCertificates
    if len(certs) == 0 {
        return nil, fmt.Errorf("no certificates received from server")
    }

    log.Printf("🌐 Received %d certificates from server 📦", len(certs))
    for i, cert := range certs {
        logCertInfo(cert, fmt.Sprintf("Server Certificate %d", i+1))
    }

    // Convert raw certificate to PEM format
    pemCert := &bytes.Buffer{}
    err = pem.Encode(pemCert, &pem.Block{
        Type:  "CERTIFICATE",
        Bytes: certs[0].Raw,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to encode certificate as PEM: %v", err)
    }

    return pemCert.Bytes(), nil
}

func main() {
    log.SetFlags(log.Ldate | log.Ltime | log.Lmicroseconds | log.Lshortfile)
    log.Println("🚀 Starting gRPC client... 🌟")

    // Load certificates from environment
    clientCertPEM := os.Getenv("PLUGIN_CLIENT_CERT")
    clientKeyPEM := os.Getenv("PLUGIN_CLIENT_KEY")
    serverCertPEM := os.Getenv("PLUGIN_SERVER_CERT")

    log.Printf("📂 Checking environment variables... 🔍")
    if clientCertPEM == "" || clientKeyPEM == "" {
        log.Fatal("❌ Missing required client certificates ⛔")
    }

    serverAddr := "localhost:50051"
    var serverCertBytes []byte
    var err error

    if serverCertPEM == "" {
        log.Printf("🔒 No server certificate provided, fetching from server... 🔄")
        serverCertBytes, err = getTrustedServerCert(serverAddr)
        if err != nil {
            log.Fatalf("❌ Failed to get server certificate: %v ⛔", err)
        }
    } else {
        log.Printf("🔒 Using provided server certificate 📜")
        serverCertBytes = []byte(serverCertPEM)
    }

    log.Printf("📦 Certificate sizes - Client Cert: %d bytes, Client Key: %d bytes, Server Cert: %d bytes 📊",
        len(clientCertPEM), len(clientKeyPEM), len(serverCertBytes))

    log.Println("🔐 Creating certificate pool... 🔄")
    certPool := x509.NewCertPool()
    if !certPool.AppendCertsFromPEM(serverCertBytes) {
        log.Fatal("❌ Failed to append server certificate to pool ⛔")
    }
    log.Printf("✅ Server certificate added to pool successfully 🔒")

    log.Println("🔑 Loading client certificate... 🔄")
    clientCert, err := tls.X509KeyPair([]byte(clientCertPEM), []byte(clientKeyPEM))
    if err != nil {
        log.Fatalf("❌ Failed to load client certificate: %v ⛔", err)
    }
    log.Printf("✅ Client certificate loaded successfully 🔒")

    if len(clientCert.Certificate) > 0 {
        cert, err := x509.ParseCertificate(clientCert.Certificate[0])
        if err != nil {
            log.Printf("⚠️ Warning: Failed to parse client certificate for logging: %v ⚠️", err)
        } else {
            logCertInfo(cert, "Client")
        }
    }

    log.Println("⚙️ Configuring TLS... 🔄")
    tlsConfig := &tls.Config{
        Certificates:       []tls.Certificate{clientCert},
        RootCAs:           certPool,
        ServerName:        "localhost",
        MinVersion:        tls.VersionTLS12,
        CurvePreferences: []tls.CurveID{tls.CurveP521, tls.CurveP384, tls.CurveP256},
    }
    log.Printf("✅ TLS configuration complete 🔒")

    kacp := keepalive.ClientParameters{
        Time:                10 * time.Second,
        Timeout:             5 * time.Second,
        PermitWithoutStream: true,
    }
    log.Printf("⚙️ Keepalive parameters configured 📊")

    log.Println("🔌 Creating gRPC connection... 🔄")
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    conn, err := grpc.DialContext(
        ctx,
        serverAddr,
        grpc.WithTransportCredentials(credentials.NewTLS(tlsConfig)),
        grpc.WithKeepaliveParams(kacp),
        grpc.WithBlock(),
    )
    if err != nil {
        log.Printf("❌ Connection details on failure:")
        log.Printf("❌   Target: %s", serverAddr)
        log.Printf("❌   TLS Version: %d", tlsConfig.MinVersion)
        log.Printf("❌   Error: %v", err)
        if stat, ok := status.FromError(err); ok {
            log.Printf("❌   gRPC Status: %s", stat.Message())
        }
        log.Fatal("❌ Failed to dial server ⛔")
    }
    defer conn.Close()
    log.Println("✅ Successfully established gRPC connection 🎉")

    client := proto.NewKVClient(conn)
    log.Println("👥 Created gRPC client 🔄")

    log.Println("📡 Sending Get request... 🔄")
    reqCtx, reqCancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer reqCancel()

    response, err := client.Get(reqCtx, &proto.GetRequest{Key: "test"})
    if err != nil {
        log.Printf("❌ Error making request: %v 🚫", err)
        if stat, ok := status.FromError(err); ok {
            log.Printf("❌ gRPC status code: %v 🚫", stat.Code())
            log.Printf("❌ gRPC status message: %v 🚫", stat.Message())
            log.Printf("❌ gRPC status details: %v 🚫", stat.Details())
        }
        os.Exit(1)
    }

    fmt.Printf("✨ Response: %s 📄\n", string(response.Value))
    log.Println("✅ Request completed successfully 🎉")
}

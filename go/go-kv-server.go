package main

import (
    "log"
    "os"
    "time"
    "net"

    "context"
    "crypto/tls"
    "crypto/x509"

    "google.golang.org/grpc"
    "google.golang.org/grpc/credentials"
    "google.golang.org/grpc/keepalive"
    "google.golang.org/grpc/peer"

    "github.com/livingstaccato/grpc-kv-examples/proto"
)

type server struct {
    proto.UnimplementedKVServer
}

func (s *server) Put(ctx context.Context, req *proto.PutRequest) (*proto.Empty, error) {
    log.Printf("Received Put request - Key: %s, Value: %s\n", req.Key, string(req.Value))
    return &proto.Empty{}, nil
}

func (s *server) Get(ctx context.Context, req *proto.GetRequest) (*proto.GetResponse, error) {
    log.Printf("Received Get request - Key: %s\n", req.Key)

    if p, ok := peer.FromContext(ctx); ok {
        log.Printf("Peer address: %v\n", p.Addr)
        if mtls, ok := p.AuthInfo.(credentials.TLSInfo); ok {
            log.Printf("TLS version: %x\n", mtls.State.Version)
            log.Printf("Cipher suite: %x\n", mtls.State.CipherSuite)
            for i, cert := range mtls.State.PeerCertificates {
                log.Printf("Client Certificate %d: Subject: %s, Issuer: %s, Serial: %s\n",
                    i, cert.Subject, cert.Issuer, cert.SerialNumber)
            }
        }
    }

    return &proto.GetResponse{Value: []byte("OK")}, nil
}

func main() {
    log.SetFlags(log.LstdFlags | log.Lshortfile)
    
    serverCertPEM := os.Getenv("PLUGIN_SERVER_CERT")
    serverKeyPEM := os.Getenv("PLUGIN_SERVER_KEY")
    clientCertPEM := os.Getenv("PLUGIN_CLIENT_CERT")

    if serverCertPEM == "" || serverKeyPEM == "" {
        log.Fatalf("PLUGIN_SERVER_CERT or PLUGIN_SERVER_KEY environment variables not set")
    }

    certPool := x509.NewCertPool()
    log.Printf("Creating certificate pool")

    if clientCertPEM != "" {
        if ok := certPool.AppendCertsFromPEM([]byte(clientCertPEM)); !ok {
            log.Fatalf("Failed to append client certificate to pool")
        }
        log.Printf("Added client certificate to pool")
    } else {
        if ok := certPool.AppendCertsFromPEM([]byte(serverCertPEM)); !ok {
            log.Fatalf("Failed to append server certificate to pool")
        }
        log.Printf("Added server certificate to pool (self-signed mode)")
    }

    cert, err := tls.X509KeyPair([]byte(serverCertPEM), []byte(serverKeyPEM))
    if err != nil {
        log.Fatalf("Failed to load server key pair: %v", err)
    }
    log.Printf("Loaded server key pair successfully")

    tlsConfig := &tls.Config{
        Certificates: []tls.Certificate{cert},
        ClientAuth:   tls.RequireAndVerifyClientCert,
        ClientCAs:    certPool,
        MinVersion:   tls.VersionTLS12,
        ServerName:   "localhost",
        // CipherSuites: []uint16{
        //     tls.TLS_AES_128_GCM_SHA256,
        //     tls.TLS_AES_256_GCM_SHA384,
        //     tls.TLS_CHACHA20_POLY1305_SHA256,
        // },
    }

    // Add keepalive options
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

    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        log.Fatalf("Failed to listen: %v", err)
    }
    log.Printf("Server listening on :50051")

    creds := credentials.NewTLS(tlsConfig)
    s := grpc.NewServer(
        grpc.Creds(creds),
        grpc.KeepaliveEnforcementPolicy(kaep),
        grpc.KeepaliveParams(kasp),
    )

    proto.RegisterKVServer(s, &server{})

    log.Printf("Starting gRPC server")
    if err := s.Serve(lis); err != nil {
        log.Fatalf("Failed to serve: %v", err)
    }
}
#!/usr/bin/env python3

import ssl
import socket
import logging
import os
from datetime import datetime
from typing import Dict, Optional, Tuple, List
import json
from dataclasses import dataclass, asdict
import sys
from rich.console import Console
from rich.table import Table
from rich import print as rprint
from rich.panel import Panel
from rich.tree import Tree
import binascii
import re
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding
from cryptography.x509.oid import NameOID

@dataclass
class ConnectionTarget:
    """Connection target details"""
    type: str  # 'tcp' or 'unix'
    address: str  # hostname:port or unix socket path
    display_address: str  # formatted address for display

    @classmethod
    def from_string(cls, target: str) -> 'ConnectionTarget':
        """Parse a connection string into a ConnectionTarget

        Formats supported:
        - hostname:port (e.g., "localhost:50051")
        - unix://path (e.g., "unix:///tmp/test.sock")
        - unix:/path (e.g., "unix:/tmp/test.sock")
        - /path (e.g., "/tmp/test.sock" - assumed to be unix socket)
        """
        if target.startswith('unix://'):
            path = target[7:]
            return cls('unix', path, f"Unix socket: {path}")
        elif target.startswith('unix:/'):
            path = target[6:]
            return cls('unix', path, f"Unix socket: {path}")
        elif target.startswith('/'):
            return cls('unix', target, f"Unix socket: {target}")
        elif ':' in target:
            host, port = target.rsplit(':', 1)
            return cls('tcp', (host, int(port)), f"TCP {host}:{port}")
        else:
            raise ValueError("Invalid connection target. Use 'host:port' or 'unix:///path' or '/path'")

@dataclass
class ConnectionInfo:
    """Connection information"""
    protocol: str
    cipher_suite: str
    cipher_bits: int
    target: ConnectionTarget
    client_auth_status: str
    alpn_protocol: Optional[str]
    session_reused: bool
    server_hostname: str
    compression: Optional[str]

@dataclass
class CertificateDetails:
    subject: Dict[str, str]
    issuer: Dict[str, str]
    version: int
    serial_number: str
    valid_from: str
    valid_until: str
    fingerprint_sha1: str
    fingerprint_sha256: str
    key_type: str
    key_size: int
    signature_algorithm: str
    extensions: List[str]
    @classmethod

    def from_cryptography_cert(cls, cert: x509.Certificate) -> 'CertificateDetails':
        subject_dict = {}
        for attribute in cert.subject:
            oid_string = attribute.oid._name
            value_string = attribute.value
            subject_dict[oid_string] = value_string

        issuer_dict = {}
        for attribute in cert.issuer:
            oid_string = attribute.oid._name
            value_string = attribute.value
            issuer_dict[oid_string] = value_string

        # Format serial number as lowercase hex with leading zeros where needed
        serial_hex = format(cert.serial_number, 'x')
        if len(serial_hex) % 2 != 0:
            serial_hex = '0' + serial_hex

        return cls(
            subject=subject_dict,
            issuer=issuer_dict,
            version=cert.version.value,
            serial_number=serial_hex.lower(),  # Ensure lowercase
            valid_from=cert.not_valid_before_utc.strftime('%Y-%m-%d %H:%M:%S UTC'),
            valid_until=cert.not_valid_after_utc.strftime('%Y-%m-%d %H:%M:%S UTC'),
            fingerprint_sha1=binascii.hexlify(cert.fingerprint(hashes.SHA1())).decode('utf-8').lower(),
            fingerprint_sha256=binascii.hexlify(cert.fingerprint(hashes.SHA256())).decode('utf-8').lower(),
            key_type=cert.public_key().__class__.__name__,
            key_size=cls._get_key_size(cert.public_key()),
            signature_algorithm=cert.signature_algorithm_oid._name,
            extensions=[ext.oid._name for ext in cert.extensions]
        )

    @staticmethod
    def _get_key_size(key) -> int:
        try:
            return key.key_size
        except AttributeError:
            return 0

def format_hex_with_colons(hex_str: str) -> str:
    """Format a hex string with colons every two characters, ensuring even length"""
    # First, ensure the hex string has an even number of characters
    if len(hex_str) % 2 != 0:
        hex_str = '0' + hex_str
    
    # Convert to lowercase and pad single digits
    hex_str = hex_str.lower()
    
    # Split into pairs and join with colons
    return ':'.join(hex_str[i:i+2] for i in range(0, len(hex_str), 2))

class TLSChecker:
    def __init__(self):
        self.console = Console()
        self.load_certificates()

    def load_certificates(self) -> None:
        """Load certificates from environment variables"""
        # These are now optional
        self.client_cert = os.getenv('PLUGIN_CLIENT_CERT')
        self.client_key = os.getenv('PLUGIN_CLIENT_KEY')
        self.server_cert = os.getenv('PLUGIN_SERVER_CERT')

        # Parse certificates if they exist
        if self.server_cert:
            self.server_cert_obj = x509.load_pem_x509_certificate(self.server_cert.encode())
        else:
            self.server_cert_obj = None

        if self.client_cert:
            self.client_cert_obj = x509.load_pem_x509_certificate(self.client_cert.encode())
        else:
            self.client_cert_obj = None


    def verify_client_auth(self, ssl_sock: ssl.SSLSocket) -> str:
        """Verify client authentication"""
        try:
            ssl_sock.write(b"VERIFY\n")
            ssl_sock.read(1024)
            return "Successful"
        except Exception as e:
            return f"Failed: {str(e)}"

    def format_subject_or_issuer(self, data: Dict[str, str]) -> str:
        """Format subject or issuer information nicely"""
        parts = []
        # Order fields in a standard way
        field_order = ['commonName', 'organizationName', 'organizationalUnitName',
                      'countryName', 'stateOrProvinceName', 'localityName']

        # Add ordered fields first
        for field in field_order:
            if field in data:
                short_name = {
                    'commonName': 'CN',
                    'organizationName': 'O',
                    'organizationalUnitName': 'OU',
                    'countryName': 'C',
                    'stateOrProvinceName': 'ST',
                    'localityName': 'L'
                }.get(field, field)
                parts.append(f"{short_name}={data[field]}")

        # Add any remaining fields
        for k, v in data.items():
            if k not in field_order:
                parts.append(f"{k}={v}")

        return ", ".join(parts)

    def display_certificate_details(self, cert_details: CertificateDetails, title: str) -> None:
        """Display detailed certificate information"""
        cert_table = Table(title=title, show_header=False)
        cert_table.add_column("Field", style="cyan")
        cert_table.add_column("Value", style="white", overflow="fold")

        # Basic Information
        cert_table.add_row("Subject", self.format_subject_or_issuer(cert_details.subject))
        cert_table.add_row("Issuer", self.format_subject_or_issuer(cert_details.issuer))
        cert_table.add_row("Valid From", cert_details.valid_from)
        cert_table.add_row("Valid Until", cert_details.valid_until)
        cert_table.add_row("Serial Number", format_hex_with_colons(cert_details.serial_number))
        cert_table.add_row("Version", f"v{cert_details.version}")

        # Fingerprints
        cert_table.add_row("SHA1 Fingerprint", format_hex_with_colons(cert_details.fingerprint_sha1))
        cert_table.add_row("SHA256 Fingerprint", format_hex_with_colons(cert_details.fingerprint_sha256))

        # Key Information
        cert_table.add_row("Public Key Type", cert_details.key_type)
        cert_table.add_row("Public Key Size", f"{cert_details.key_size} bits")
        cert_table.add_row("Signature Algorithm", cert_details.signature_algorithm)

        # Extensions
        if cert_details.extensions:
            cert_table.add_row("Extensions", "\n".join(f"• {ext}" for ext in cert_details.extensions))

        self.console.print(cert_table)
        self.console.print()

    def display_connection_details(self, conn_info: ConnectionInfo) -> None:
        """Display connection details"""
        conn_table = Table(title="Connection Details", show_header=False)
        conn_table.add_column("Field", style="cyan")
        conn_table.add_column("Value", style="white")

        conn_table.add_row("Connection Type", conn_info.target.type.upper())
        conn_table.add_row("Connected To", conn_info.target.display_address)
        conn_table.add_row("Protocol Version", conn_info.protocol)
        conn_table.add_row("Cipher Suite", conn_info.cipher_suite)
        conn_table.add_row("Cipher Strength", f"{conn_info.cipher_bits} bits")

        if conn_info.target.type == 'tcp':
            conn_table.add_row("Server Hostname", conn_info.server_hostname)

        if conn_info.alpn_protocol:
            conn_table.add_row("ALPN Protocol", conn_info.alpn_protocol)
        if conn_info.session_reused:
            conn_table.add_row("Session Reused", "Yes")
        if conn_info.compression:
            conn_table.add_row("Compression", conn_info.compression)

        self.console.print(conn_table)
        self.console.print()

    def create_connection(self, target: ConnectionTarget) -> socket.socket:
        """Create appropriate socket based on target type"""
        if target.type == 'unix':
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        else:  # tcp
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        return sock

    def create_ssl_context(self, is_unix_socket=False) -> ssl.SSLContext:
        """Create and configure SSL context based on available certificates"""
        context = ssl.create_default_context(ssl.Purpose.SERVER_AUTH)
        
        # For Unix sockets, disable hostname checking and certificate verification
        if is_unix_socket:
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
        
        # Load client certificate and key if available
        if self.client_cert and self.client_key:
            import tempfile
            with tempfile.NamedTemporaryFile(delete=False) as cert_file, \
                 tempfile.NamedTemporaryFile(delete=False) as key_file:
                try:
                    cert_file.write(self.client_cert.encode())
                    cert_file.flush()
                    key_file.write(self.client_key.encode())
                    key_file.flush()
                    context.load_cert_chain(certfile=cert_file.name, keyfile=key_file.name)
                finally:
                    os.unlink(cert_file.name)
                    os.unlink(key_file.name)

        # If server cert is provided, verify against it
        if self.server_cert:
            context.load_verify_locations(cadata=self.server_cert)
        elif not is_unix_socket:  # Only disable verification for non-Unix sockets if no cert provided
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
        
        return context

    def check_connection(self, target_str: str = 'localhost:50051') -> None:
        """Perform TLS connection check and display results"""
        target = ConnectionTarget.from_string(target_str)
        
        try:
            self.console.print(f"\n[blue]1. Creating SSL context...[/blue]")
            context = self.create_ssl_context(is_unix_socket=target.type == 'unix')
            
            self.console.print(f"[blue]2. Creating base socket...[/blue]")
            sock = self.create_connection(target)
            
            self.console.print(f"[blue]3. Wrapping socket with SSL...[/blue]")
            
            # For Unix sockets, connect first then wrap
            if target.type == 'unix':
                self.console.print(f"[blue]3a. Unix socket - connecting first...[/blue]")
                sock.connect(target.address)
                ssl_sock = context.wrap_socket(sock)  # No server_hostname for Unix socket
            else:
                self.console.print(f"[blue]3b. TCP socket - wrapping then connecting...[/blue]")
                ssl_sock = context.wrap_socket(sock, server_hostname=target.address[0])
                ssl_sock.connect(target.address)
            
            try:
                with ssl_sock:
                    self.console.print(f"\n[bold blue]Establishing TLS Connection to {target.display_address}...[/bold blue]")
                    
                    self.console.print(f"[blue]4. Getting peer certificate...[/blue]")
                    if not self.server_cert_obj:
                        cert_binary = ssl_sock.getpeercert(binary_form=True)
                        if cert_binary:
                            self.server_cert_obj = x509.load_der_x509_certificate(cert_binary)
                    
                    self.console.print(f"[blue]5. Getting connection info...[/blue]")
                    # Get connection info
                    conn_info = ConnectionInfo(
                        protocol=ssl_sock.version(),
                        cipher_suite=ssl_sock.cipher()[0],
                        cipher_bits=ssl_sock.cipher()[2],
                        target=target,
                        client_auth_status=self.verify_client_auth(ssl_sock),
                        alpn_protocol=ssl_sock.selected_alpn_protocol(),
                        session_reused=ssl_sock.session_reused,
                        server_hostname="",  # Empty for Unix sockets
                        compression=ssl_sock.compression()
                    )
                    # Success banner
                    self.console.print(f"\n[green]✓ Connection Established Successfully to {target.display_address}[/green]\n")

                    # Display certificate and connection information
                    if self.server_cert_obj:
                        server_cert_details = CertificateDetails.from_cryptography_cert(self.server_cert_obj)
                        self.display_certificate_details(server_cert_details, "Server Certificate")

                    if self.client_cert_obj:
                        client_cert_details = CertificateDetails.from_cryptography_cert(self.client_cert_obj)
                        self.display_certificate_details(client_cert_details, "Client Certificate")

                    self.display_connection_details(conn_info)

                    # Client Authentication Status
                    status_color = "green" if "Successful" in conn_info.client_auth_status else "red"
                    self.console.print(f"[bold]Client Authentication Status:[/bold] [{status_color}]{conn_info.client_auth_status}[/{status_color}]\n")
            finally:
                ssl_sock.close()

        except Exception as e:
            self.console.print(f"\n[red]Error:[/red] {str(e)}", style="bold red")
            self.console.print(f"[red]Error type:[/red] {type(e).__name__}")
            import traceback
            self.console.print("[red]Traceback:[/red]\n" + traceback.format_exc())

def main():
    import argparse
    parser = argparse.ArgumentParser(description='TLS Connection Checker')
    parser.add_argument('target', nargs='?', default='localhost:50051',
                      help='Connection target. Can be host:port or unix:///path or /path')
    args = parser.parse_args()

    checker = TLSChecker()
    checker.check_connection(args.target)

if __name__ == "__main__":
    main()

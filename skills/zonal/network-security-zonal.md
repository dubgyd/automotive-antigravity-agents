# Network Security for Zonal Architecture

**Category:** automotive-zonal
**Version:** 1.0.0
**Maturity:** production
**Complexity:** advanced

## Overview

Expert knowledge in securing automotive Ethernet networks in zonal architectures. Covers MACsec (IEEE 802.1AE), IPsec, firewall rules for zone controllers, intrusion detection systems (IDS), secure gateway design, and IDPS deployment for vehicle networks.

## Core Competencies

### 1. MACsec (IEEE 802.1AE) - Layer 2 Encryption

```c
// MACsec Configuration for Automotive Ethernet
typedef struct {
    uint8_t enabled;
    uint8_t cipher_suite;       // AES-GCM-128 or AES-GCM-256
    uint8_t confidentiality;    // Encrypt payload
    uint8_t integrity;          // ICV (Integrity Check Value)
    uint32_t pn;                // Packet Number (anti-replay)
    uint8_t key[32];            // 128-bit or 256-bit key
    uint8_t sci[8];             // Secure Channel Identifier
} MACSec_Config_t;

// Example: MACsec between gateway and zone controller
MACSec_Config_t macsec_link = {
    .enabled = 1,
    .cipher_suite = AES_GCM_256,
    .confidentiality = 1,       // Encrypt
    .integrity = 1,             // 16-byte ICV
    .pn = 0x00000001,          // Initial packet number
    .key = {0x2b, 0x7e, 0x15, ...},  // 256-bit key from key management
    .sci = {0x00, 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77}
};
```

**MACsec Frame Structure:**
```
┌──────────────────────────────────────────────┐
│ Ethernet Header (14 bytes)                   │
├──────────────────────────────────────────────┤
│ SecTAG (8 bytes)                             │
│  - TCI/AN (1 byte): Version, encrypted flag │
│  - SL (1 byte): Short Length                │
│  - PN (4 bytes): Packet Number              │
│  - SCI (8 bytes): Secure Channel ID         │
├──────────────────────────────────────────────┤
│ Encrypted Payload                            │
├──────────────────────────────────────────────┤
│ ICV (16 bytes): Integrity Check Value        │
└──────────────────────────────────────────────┘
```

**Performance Impact:**
- Latency overhead: ~100-200 μs
- Throughput reduction: ~5-10% (due to encryption)
- CPU overhead: ~15% on zone controller

### 2. IPsec for End-to-End Security

```python
class IPsecTunnel:
    """
    IPsec tunnel configuration for secure SOME/IP communication.
    """

    def __init__(self):
        self.mode = 'ESP'  # Encapsulating Security Payload
        self.encryption = 'AES-256-CBC'
        self.authentication = 'HMAC-SHA256'
        self.pfs = True  # Perfect Forward Secrecy

    def configure_tunnel(self, local_ip, remote_ip):
        """
        Configure IPsec tunnel between two ECUs.

        Args:
            local_ip: Local zone controller IP
            remote_ip: Remote zone controller/gateway IP
        """

        config = {
            'src': local_ip,
            'dst': remote_ip,
            'protocol': 'ESP',  # ESP for encryption + auth
            'spi': 0x1234,  # Security Parameter Index
            'encryption': {
                'algorithm': 'AES-256-CBC',
                'key': self._generate_key(256)
            },
            'authentication': {
                'algorithm': 'HMAC-SHA256',
                'key': self._generate_key(256)
            },
            'lifetime': 3600,  # Rekey every hour
            'anti_replay': True,
            'window_size': 64
        }

        return config

    def _generate_key(self, bits):
        """Generate cryptographic key (placeholder - use proper KMS)."""
        import secrets
        return secrets.token_bytes(bits // 8)

# Example: Secure tunnel from FL zone to gateway
tunnel = IPsecTunnel()
config = tunnel.configure_tunnel(
    local_ip='192.168.1.10',   # FL Zone Controller
    remote_ip='192.168.1.1'     # Gateway
)
```

### 3. Firewall Rules for Zone Controllers

```python
class ZonalFirewall:
    """
    Stateful firewall for zone controller Ethernet interface.
    """

    def __init__(self, zone_id):
        self.zone_id = zone_id
        self.rules = []
        self.default_policy = 'DROP'  # Deny by default

    def add_rule(self, rule):
        """
        Add firewall rule.

        Rule format:
        {
            'src_ip': '192.168.1.0/24',
            'dst_ip': '192.168.2.10',
            'protocol': 'UDP',
            'dst_port': 30500,
            'action': 'ALLOW'/'DROP'/'REJECT',
            'priority': 100
        }
        """
        self.rules.append(rule)
        # Sort by priority
        self.rules.sort(key=lambda x: x['priority'])

    def evaluate_packet(self, packet):
        """
        Evaluate packet against firewall rules.

        Returns:
            'ALLOW', 'DROP', or 'REJECT'
        """

        for rule in self.rules:
            if self._match_rule(packet, rule):
                return rule['action']

        return self.default_policy

    def _match_rule(self, packet, rule):
        """Check if packet matches rule."""
        # Check source IP
        if not self._ip_in_subnet(packet['src_ip'], rule.get('src_ip', 'any')):
            return False

        # Check destination IP
        if not self._ip_in_subnet(packet['dst_ip'], rule.get('dst_ip', 'any')):
            return False

        # Check protocol
        if rule.get('protocol', 'any') != 'any' and packet['protocol'] != rule['protocol']:
            return False

        # Check port
        if rule.get('dst_port') and packet.get('dst_port') != rule['dst_port']:
            return False

        return True

# Example: Firewall rules for FL Zone Controller
fw = ZonalFirewall(zone_id='FL_ZONE')

# Allow SOME/IP from gateway
fw.add_rule({
    'src_ip': '192.168.1.1',     # Gateway
    'dst_ip': '192.168.1.10',     # FL Zone
    'protocol': 'UDP',
    'dst_port': 30500,            # SOME/IP service port
    'action': 'ALLOW',
    'priority': 100
})

# Allow diagnostic access (DoIP)
fw.add_rule({
    'src_ip': '192.168.5.0/24',   # Diagnostic VLAN
    'dst_ip': '192.168.1.10',
    'protocol': 'TCP',
    'dst_port': 13400,            # DoIP port
    'action': 'ALLOW',
    'priority': 200
})

# Block all other incoming traffic
fw.add_rule({
    'src_ip': 'any',
    'dst_ip': '192.168.1.10',
    'action': 'DROP',
    'priority': 1000
})
```

### 4. Intrusion Detection System (IDS)

```python
class AutomotiveIDS:
    """
    Intrusion Detection System for automotive Ethernet networks.
    Detects anomalies and attacks specific to vehicle networks.
    """

    def __init__(self):
        self.baseline = {}  # Normal traffic patterns
        self.alerts = []

    def detect_anomalies(self, traffic_sample):
        """
        Detect network anomalies.

        Detection methods:
        - Signature-based: Known attack patterns
        - Anomaly-based: Deviation from baseline
        - Behavior-based: Unusual communication patterns
        """

        alerts = []

        # 1. Port scan detection
        if self._detect_port_scan(traffic_sample):
            alerts.append({
                'type': 'PORT_SCAN',
                'severity': 'HIGH',
                'description': 'Port scan detected from ' + traffic_sample['src_ip']
            })

        # 2. DoS detection (flooding)
        if self._detect_dos(traffic_sample):
            alerts.append({
                'type': 'DOS_ATTACK',
                'severity': 'CRITICAL',
                'description': 'Potential DoS attack detected'
            })

        # 3. Unusual SOME/IP service access
        if self._detect_unauthorized_service_access(traffic_sample):
            alerts.append({
                'type': 'UNAUTHORIZED_ACCESS',
                'severity': 'HIGH',
                'description': 'Unauthorized SOME/IP service access'
            })

        # 4. ARP spoofing detection
        if self._detect_arp_spoofing(traffic_sample):
            alerts.append({
                'type': 'ARP_SPOOFING',
                'severity': 'CRITICAL',
                'description': 'ARP spoofing detected'
            })

        # 5. Replay attack detection (abnormal packet rate)
        if self._detect_replay(traffic_sample):
            alerts.append({
                'type': 'REPLAY_ATTACK',
                'severity': 'MEDIUM',
                'description': 'Potential replay attack detected'
            })

        return alerts

    def _detect_port_scan(self, traffic):
        """
        Detect port scanning:
        - Multiple connection attempts to different ports
        - From same source IP in short time window
        """

        src_ip = traffic.get('src_ip')
        unique_ports = traffic.get('unique_dst_ports', [])
        time_window = traffic.get('time_window_sec', 0)

        # More than 20 ports in 10 seconds = port scan
        if len(unique_ports) > 20 and time_window < 10:
            return True

        return False

    def _detect_dos(self, traffic):
        """
        Detect Denial of Service:
        - Packet rate > 10x baseline
        - Same message repeated at high rate
        """

        pkt_rate = traffic.get('packets_per_second', 0)
        baseline_rate = self.baseline.get('avg_pkt_rate', 100)

        if pkt_rate > baseline_rate * 10:
            return True

        return False

    def _detect_unauthorized_service_access(self, traffic):
        """
        Detect unauthorized SOME/IP service access:
        - Access to service not in whitelist
        - Access from unauthorized client
        """

        service_id = traffic.get('someip_service_id')
        client_ip = traffic.get('src_ip')

        authorized_services = {
            0x1234: ['192.168.1.1'],  # Battery service - gateway only
            0x5678: ['192.168.1.1', '192.168.1.10']  # Body service - gateway + FL zone
        }

        if service_id in authorized_services:
            if client_ip not in authorized_services[service_id]:
                return True

        return False

    def _detect_arp_spoofing(self, traffic):
        """
        Detect ARP spoofing:
        - Different MAC for same IP
        - Gratuitous ARP with conflicting info
        """

        if traffic.get('protocol') == 'ARP':
            ip = traffic.get('ip')
            mac = traffic.get('mac')

            known_mac = self.baseline.get('ip_to_mac', {}).get(ip)

            if known_mac and known_mac != mac:
                return True  # MAC changed for this IP

        return False

    def _detect_replay(self, traffic):
        """
        Detect replay attacks:
        - Same packet repeated (duplicate sequence numbers)
        - Packet rate anomaly for specific message
        """

        msg_id = traffic.get('msg_id')
        pkt_count = traffic.get('pkt_count', 0)
        baseline_count = self.baseline.get('msg_counts', {}).get(msg_id, 1)

        if pkt_count > baseline_count * 5:
            return True

        return False
```

### 5. Secure Gateway Design

```c
// Secure gateway functionality
typedef struct {
    uint8_t zone_count;
    struct {
        uint8_t zone_id;
        uint32_t ip_address;
        uint8_t vlan_id;
        bool macsec_enabled;
        bool ipsec_enabled;
        bool firewall_enabled;
    } zones[8];

    struct {
        bool ids_enabled;
        bool ips_enabled;           // Intrusion Prevention
        uint16_t alert_threshold;
        char siem_server[64];       // SIEM logging
    } security;

} SecureGateway_t;

// Example gateway configuration
SecureGateway_t gateway = {
    .zone_count = 4,
    .zones = {
        {.zone_id = 1, .ip_address = 0xC0A80110, .vlan_id = 100, .macsec_enabled = true, .ipsec_enabled = false, .firewall_enabled = true},  // FL Zone
        {.zone_id = 2, .ip_address = 0xC0A80120, .vlan_id = 100, .macsec_enabled = true, .ipsec_enabled = false, .firewall_enabled = true},  // FR Zone
        {.zone_id = 3, .ip_address = 0xC0A80130, .vlan_id = 200, .macsec_enabled = true, .ipsec_enabled = true, .firewall_enabled = true},   // ADAS Zone (extra IPsec)
        {.zone_id = 4, .ip_address = 0xC0A80140, .vlan_id = 100, .macsec_enabled = true, .ipsec_enabled = false, .firewall_enabled = true}   // RL Zone
    },

    .security = {
        .ids_enabled = true,
        .ips_enabled = true,        // Block detected attacks automatically
        .alert_threshold = 10,      // Alert after 10 suspicious events
        .siem_server = "192.168.99.10"
    }
};
```

## Security Architecture Layers

```
┌────────────────────────────────────────────┐
│  Layer 7: Application Security            │
│  - SOME/IP authentication                 │
│  - Service access control                 │
└────────────────────────────────────────────┘
┌────────────────────────────────────────────┐
│  Layer 4-6: Transport/Session Security    │
│  - IPsec (ESP): End-to-end encryption     │
│  - TLS 1.3: For diagnostic protocols      │
└────────────────────────────────────────────┘
┌────────────────────────────────────────────┐
│  Layer 3: Network Security                │
│  - Firewall: Packet filtering             │
│  - IDS/IPS: Anomaly detection             │
└────────────────────────────────────────────┘
┌────────────────────────────────────────────┐
│  Layer 2: Data Link Security              │
│  - MACsec (IEEE 802.1AE): Link encryption │
│  - 802.1X: Port-based authentication      │
└────────────────────────────────────────────┘
```

## Key Management

```python
class VehicleKeyManagement:
    """
    Key management for MACsec and IPsec.
    Supports both static provisioning and dynamic key exchange.
    """

    def __init__(self):
        self.keys = {}
        self.key_lifetime_hours = 24  # Rotate every 24 hours

    def provision_static_key(self, zone_id, key_type, key_material):
        """
        Provision static key during manufacturing.

        Args:
            zone_id: Zone controller ID
            key_type: 'MACSEC' or 'IPSEC'
            key_material: 256-bit key
        """

        self.keys[zone_id] = {
            'type': key_type,
            'key': key_material,
            'provisioned_at': time.time(),
            'valid_until': time.time() + (self.key_lifetime_hours * 3600)
        }

    def rotate_keys(self):
        """
        Automatic key rotation every 24 hours.
        Uses Diffie-Hellman key exchange for new keys.
        """

        for zone_id, key_info in self.keys.items():
            if time.time() > key_info['valid_until']:
                # Generate new key
                new_key = self._dh_key_exchange(zone_id)
                self.keys[zone_id]['key'] = new_key
                self.keys[zone_id]['valid_until'] = time.time() + (self.key_lifetime_hours * 3600)

    def _dh_key_exchange(self, zone_id):
        """Diffie-Hellman key exchange (simplified)."""
        # In production, use proper DH or ECDH
        import secrets
        return secrets.token_bytes(32)  # 256-bit key
```

## Performance Impact

| Security Feature | Latency Overhead | CPU Overhead | Throughput Impact |
|------------------|------------------|--------------|-------------------|
| MACsec (AES-128) | +100 μs | +10% | -5% |
| MACsec (AES-256) | +150 μs | +15% | -8% |
| IPsec (ESP) | +200 μs | +20% | -10% |
| Firewall | +50 μs | +5% | -2% |
| IDS (passive) | +10 μs | +8% | 0% |
| IPS (active) | +100 μs | +15% | -5% |

## Tools & Testing

- **Wireshark with MACsec plugin** - Decrypt and analyze MACsec traffic
- **Scapy** - Craft attack packets for security testing
- **Suricata** - Open-source IDS/IPS engine
- **Kali Linux** - Penetration testing toolkit
- **CANalyze** - Automotive-specific security testing

## References

- IEEE 802.1AE (MACsec) Standard
- ISO/SAE 21434 Cybersecurity Engineering
- UNECE R155 Cybersecurity Regulation
- AUTOSAR Secure Communication Specification

import Foundation

/// Bundled in-code lookup tables. Small enough to fit inline; keeps
/// the .app self-contained (no resource files to load).
enum Lookups {

    /// Common ports — service name + brief description.
    static let ports: [(port: Int, name: String, description: String)] = [
        (20,   "FTP-DATA", "File Transfer Protocol (data)"),
        (21,   "FTP",      "File Transfer Protocol (control)"),
        (22,   "SSH",      "Secure Shell"),
        (23,   "Telnet",   "Telnet"),
        (25,   "SMTP",     "Simple Mail Transfer Protocol"),
        (53,   "DNS",      "Domain Name System"),
        (67,   "DHCP",     "DHCP server"),
        (68,   "DHCP",     "DHCP client"),
        (69,   "TFTP",     "Trivial File Transfer Protocol"),
        (80,   "HTTP",     "Hypertext Transfer Protocol"),
        (88,   "Kerberos", "Kerberos auth"),
        (110,  "POP3",     "Post Office Protocol v3"),
        (111,  "RPCBind",  "ONC RPC portmapper"),
        (123,  "NTP",      "Network Time Protocol"),
        (135,  "MSRPC",    "Microsoft RPC"),
        (137,  "NetBIOS",  "NetBIOS name service"),
        (139,  "NetBIOS",  "NetBIOS session service"),
        (143,  "IMAP",     "Internet Message Access Protocol"),
        (161,  "SNMP",     "Simple Network Management Protocol"),
        (162,  "SNMPtrap", "SNMP trap"),
        (179,  "BGP",      "Border Gateway Protocol"),
        (194,  "IRC",      "Internet Relay Chat"),
        (389,  "LDAP",     "Lightweight Directory Access Protocol"),
        (443,  "HTTPS",    "HTTP over TLS"),
        (445,  "SMB",      "Server Message Block"),
        (465,  "SMTPS",    "SMTP over TLS (legacy)"),
        (514,  "Syslog",   "Syslog"),
        (515,  "LPD",      "Line Printer Daemon"),
        (587,  "SMTP",     "SMTP submission"),
        (631,  "IPP",      "Internet Printing Protocol"),
        (636,  "LDAPS",    "LDAP over TLS"),
        (873,  "rsync",    "rsync"),
        (993,  "IMAPS",    "IMAP over TLS"),
        (995,  "POP3S",    "POP3 over TLS"),
        (1080, "SOCKS",    "SOCKS proxy"),
        (1194, "OpenVPN",  "OpenVPN"),
        (1433, "MSSQL",    "Microsoft SQL Server"),
        (1521, "Oracle",   "Oracle Database"),
        (1723, "PPTP",     "Point-to-Point Tunneling Protocol"),
        (2049, "NFS",      "Network File System"),
        (2375, "Docker",   "Docker daemon (insecure)"),
        (2376, "Docker",   "Docker daemon (TLS)"),
        (3000, "Dev",      "Common Node/Rails dev server"),
        (3306, "MySQL",    "MySQL / MariaDB"),
        (3389, "RDP",      "Remote Desktop Protocol"),
        (4000, "Phoenix",  "Phoenix dev server"),
        (4200, "Angular",  "Angular dev server"),
        (5000, "Flask",    "Common Flask / .NET dev"),
        (5173, "Vite",     "Vite dev server"),
        (5222, "XMPP",     "XMPP client connection"),
        (5269, "XMPP",     "XMPP server-to-server"),
        (5353, "mDNS",     "Multicast DNS / Bonjour"),
        (5432, "PostgreSQL", "PostgreSQL"),
        (5601, "Kibana",   "Kibana"),
        (5672, "AMQP",     "RabbitMQ / AMQP"),
        (5900, "VNC",      "Virtual Network Computing"),
        (6379, "Redis",    "Redis"),
        (6443, "Kubernetes", "Kubernetes API server"),
        (7000, "Cassandra", "Cassandra inter-node"),
        (8000, "Dev",      "Common dev server"),
        (8080, "HTTP-alt", "HTTP alternate / proxies"),
        (8086, "InfluxDB", "InfluxDB HTTP API"),
        (8443, "HTTPS-alt","HTTPS alternate"),
        (8888, "Jupyter",  "Jupyter Notebook"),
        (9000, "SonarQube","SonarQube / PHP-FPM"),
        (9092, "Kafka",    "Apache Kafka"),
        (9200, "Elasticsearch", "Elasticsearch HTTP"),
        (9300, "Elasticsearch", "Elasticsearch transport"),
        (11211,"Memcached","Memcached"),
        (27017,"MongoDB",  "MongoDB"),
        (32768,"Linux",    "Ephemeral port range start"),
    ]

    /// Common HTTP status codes — code + reason + description.
    static let httpStatuses: [(code: Int, reason: String, description: String)] = [
        (100, "Continue",            "Continue the request"),
        (101, "Switching Protocols", "Protocol upgrade"),
        (200, "OK",                  "Request succeeded"),
        (201, "Created",             "Resource created"),
        (202, "Accepted",            "Accepted for processing"),
        (204, "No Content",          "Success, no body"),
        (206, "Partial Content",     "Range request served"),
        (301, "Moved Permanently",   "Resource moved (permanent)"),
        (302, "Found",               "Temporary redirect"),
        (303, "See Other",           "Redirect (use GET)"),
        (304, "Not Modified",        "Cached version is fresh"),
        (307, "Temporary Redirect",  "Temporary, keep method"),
        (308, "Permanent Redirect",  "Permanent, keep method"),
        (400, "Bad Request",         "Malformed request"),
        (401, "Unauthorized",        "Authentication required"),
        (402, "Payment Required",    "Reserved (rarely used)"),
        (403, "Forbidden",           "Authenticated but not allowed"),
        (404, "Not Found",           "No resource at this URI"),
        (405, "Method Not Allowed",  "HTTP method not allowed"),
        (406, "Not Acceptable",      "Can't satisfy Accept header"),
        (408, "Request Timeout",     "Client timed out"),
        (409, "Conflict",            "Resource state conflict"),
        (410, "Gone",                "Resource permanently removed"),
        (411, "Length Required",     "Missing Content-Length"),
        (413, "Payload Too Large",   "Body too big"),
        (414, "URI Too Long",        "URI too long"),
        (415, "Unsupported Media Type", "Body type rejected"),
        (418, "I'm a teapot",        "April fools' joke (RFC 2324)"),
        (422, "Unprocessable Entity","Semantically invalid"),
        (425, "Too Early",           "Server refuses to risk replay"),
        (429, "Too Many Requests",   "Rate limited"),
        (451, "Unavailable for Legal Reasons", "Legal block"),
        (500, "Internal Server Error", "Generic server error"),
        (501, "Not Implemented",     "Method not supported"),
        (502, "Bad Gateway",         "Upstream returned invalid"),
        (503, "Service Unavailable", "Overload / maintenance"),
        (504, "Gateway Timeout",     "Upstream timed out"),
        (505, "HTTP Version Not Supported", "Version unsupported"),
        (511, "Network Authentication Required", "Captive portal"),
    ]

    static func searchPorts(_ query: String) -> [(port: Int, name: String, description: String)] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return [] }
        // If numeric, match port exactly + nearby.
        if let p = Int(q) {
            return ports.filter { $0.port == p }
        }
        return ports.filter {
            $0.name.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }
    }

    static func searchHTTP(_ query: String) -> [(code: Int, reason: String, description: String)] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty { return [] }
        if let c = Int(q) {
            return httpStatuses.filter { $0.code == c }
        }
        return httpStatuses.filter {
            $0.reason.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }
    }
}

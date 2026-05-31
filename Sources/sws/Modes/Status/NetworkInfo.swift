import Foundation

/// Lightweight network info — local IPv4 + public IP (cached) + a
/// crude VPN detection.
final class NetworkInfo {
    static let shared = NetworkInfo()

    private(set) var publicIP: String?
    private(set) var publicIPLastFetched: Date?
    private let publicIPMaxAge: TimeInterval = 5 * 60

    private init() {}

    /// Synchronously walks getifaddrs and returns the first non-loopback IPv4.
    func localIPv4() -> String? {
        var addresses: [String] = []
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let first = ifaddrs else { return nil }
        defer { freeifaddrs(ifaddrs) }
        var node = first
        while true {
            let flags = node.pointee.ifa_flags
            let family = node.pointee.ifa_addr?.pointee.sa_family
            if family == UInt8(AF_INET),
               (flags & UInt32(IFF_LOOPBACK)) == 0,
               (flags & UInt32(IFF_UP)) != 0 {
                var addr = node.pointee.ifa_addr!.pointee
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(&addr, socklen_t(addr.sa_len),
                               &hostname, socklen_t(NI_MAXHOST),
                               nil, 0, NI_NUMERICHOST) == 0 {
                    let s = String(cString: hostname)
                    addresses.append(s)
                }
            }
            guard let next = node.pointee.ifa_next else { break }
            node = next
        }
        // Prefer non-link-local (skip 169.254.*).
        return addresses.first { !$0.hasPrefix("169.254.") } ?? addresses.first
    }

    /// True if any active interface is named like a VPN tunnel.
    func vpnLikely() -> Bool {
        var ifaddrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrs) == 0, let first = ifaddrs else { return false }
        defer { freeifaddrs(ifaddrs) }
        var node = first
        while true {
            let flags = node.pointee.ifa_flags
            if let name = node.pointee.ifa_name {
                let n = String(cString: name)
                if (flags & UInt32(IFF_UP)) != 0,
                   (n.hasPrefix("utun") || n.hasPrefix("ppp") || n.hasPrefix("ipsec") || n.hasPrefix("tap") || n.hasPrefix("tun")) {
                    return true
                }
            }
            guard let next = node.pointee.ifa_next else { break }
            node = next
        }
        return false
    }

    /// Refresh the cached public IP if older than `publicIPMaxAge`.
    /// Completion fires on the main queue.
    func refreshPublicIP(force: Bool = false, completion: ((String?) -> Void)? = nil) {
        if !force, let last = publicIPLastFetched, Date().timeIntervalSince(last) < publicIPMaxAge,
           let ip = publicIP {
            completion?(ip)
            return
        }
        guard let url = URL(string: "https://api.ipify.org") else {
            completion?(nil); return
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 4
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            let ip = data.flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                self?.publicIP = ip
                self?.publicIPLastFetched = Date()
                completion?(ip)
            }
        }.resume()
    }
}

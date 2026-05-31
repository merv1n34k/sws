import Foundation
import CoreWLAN

enum WiFiInfo {
    struct Snapshot {
        var ssid: String?
        var rssi: Int?     // dBm
        var channel: Int?
    }

    static func current() -> Snapshot {
        let client = CWWiFiClient.shared()
        guard let iface = client.interface() else {
            return Snapshot(ssid: ssidViaNetworksetup(), rssi: nil, channel: nil)
        }
        // On macOS Sonoma+, CWInterface.ssid() returns nil unless the
        // process has Location Services permission. Fall back to the
        // `networksetup` CLI which doesn't require it.
        let ssid = iface.ssid() ?? ssidViaNetworksetup(interface: iface.interfaceName)
        let rssi = iface.rssiValue() == 0 ? nil : iface.rssiValue()
        let channel = iface.wlanChannel()?.channelNumber
        return Snapshot(ssid: ssid, rssi: rssi, channel: channel)
    }

    /// Best-effort SSID lookup via `networksetup -getairportnetwork`.
    /// Doesn't need Location Services. ~5 ms cost.
    private static func ssidViaNetworksetup(interface: String? = nil) -> String? {
        let device = interface ?? "en0"
        let task = Process()
        task.launchPath = "/usr/sbin/networksetup"
        task.arguments = ["-getairportnetwork", device]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        // "Current Wi-Fi Network: <ssid>\n" on success.
        // "You are not associated with an AirPort network." otherwise.
        let prefix = "Current Wi-Fi Network: "
        guard let range = out.range(of: prefix) else { return nil }
        return String(out[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

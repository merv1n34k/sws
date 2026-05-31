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
        guard let iface = client.interface() else { return Snapshot() }
        return Snapshot(
            ssid: iface.ssid(),
            rssi: iface.rssiValue() == 0 ? nil : iface.rssiValue(),
            channel: iface.wlanChannel()?.channelNumber
        )
    }
}

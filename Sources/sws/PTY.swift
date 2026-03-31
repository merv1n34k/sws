import Foundation
import Darwin

final class PTY {
    private var masterFD: Int32 = -1
    private var childPID: pid_t = -1
    private var readSource: DispatchSourceRead?
    var onOutput: ((Data) -> Void)?
    var onExit: (() -> Void)?

    var isRunning: Bool { childPID > 0 }

    func start(command: String, args: [String]) {
        stop()

        var masterFD: Int32 = 0
        var winSize = winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0)

        let pid = forkpty(&masterFD, nil, nil, &winSize)
        if pid < 0 {
            NSLog("SWS: forkpty failed: \(String(cString: strerror(errno)))")
            return
        }

        if pid == 0 {
            // Child process
            let cCommand = strdup(command)
            var cArgs = [cCommand]
            for arg in args {
                cArgs.append(strdup(arg))
            }
            cArgs.append(nil)
            execvp(command, &cArgs)
            // If exec fails
            perror("execvp")
            _exit(1)
        }

        // Parent
        self.masterFD = masterFD
        self.childPID = pid

        // Non-blocking reads
        let flags = fcntl(masterFD, F_GETFL)
        _ = fcntl(masterFD, F_SETFL, flags | O_NONBLOCK)

        let source = DispatchSource.makeReadSource(fileDescriptor: masterFD, queue: .global(qos: .userInteractive))
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            var buffer = [UInt8](repeating: 0, count: 4096)
            let n = read(self.masterFD, &buffer, buffer.count)
            if n > 0 {
                let data = Data(buffer[0..<n])
                DispatchQueue.main.async {
                    self.onOutput?(data)
                }
            } else if n <= 0 {
                self.readSource?.cancel()
                DispatchQueue.main.async {
                    self.onExit?()
                }
            }
        }
        source.setCancelHandler { [weak self] in
            if let fd = self?.masterFD, fd >= 0 {
                close(fd)
                self?.masterFD = -1
            }
        }
        source.resume()
        self.readSource = source

        NSLog("SWS: started \(command) (pid=\(pid))")
    }

    func write(_ data: Data) {
        guard masterFD >= 0 else { return }
        data.withUnsafeBytes { ptr in
            if let base = ptr.baseAddress {
                Darwin.write(masterFD, base, data.count)
            }
        }
    }

    func write(_ string: String) {
        if let data = string.data(using: .utf8) {
            write(data)
        }
    }

    func resize(cols: UInt16, rows: UInt16) {
        guard masterFD >= 0 else { return }
        var ws = winsize(ws_row: rows, ws_col: cols, ws_xpixel: 0, ws_ypixel: 0)
        _ = ioctl(masterFD, TIOCSWINSZ, &ws)
    }

    func stop() {
        readSource?.cancel()
        readSource = nil
        if childPID > 0 {
            kill(childPID, SIGTERM)
            var status: Int32 = 0
            waitpid(childPID, &status, WNOHANG)
            childPID = -1
        }
        if masterFD >= 0 {
            close(masterFD)
            masterFD = -1
        }
    }

    deinit {
        stop()
    }
}

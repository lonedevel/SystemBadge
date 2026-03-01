import Foundation
import Darwin
import IOKit

actor PerformanceSampler {
    private var lastCPUSample: [UInt64]?
    private var lastNetworkSample: (bytesIn: UInt64, bytesOut: UInt64, timestamp: TimeInterval)?
    private let shell = Shell()
    private var lastDiskSample: (readBytes: UInt64, writeBytes: UInt64, timestamp: TimeInterval)?

    func cpuUsagePercent() -> Double? {
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0
        var numCPUs: natural_t = 0
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let cpuInfo else {
            return nil
        }

        defer {
            let size = Int(numCPUInfo) * MemoryLayout<integer_t>.stride
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(size))
        }

        let infoBuffer = UnsafeBufferPointer(start: cpuInfo, count: Int(numCPUInfo))
        let info = infoBuffer.map { UInt64($0) }
        guard let last = lastCPUSample, last.count == info.count else {
            lastCPUSample = info
            return nil
        }

        var totalTicks: Double = 0
        var usedTicks: Double = 0
        let cpuStateCount = Int(CPU_STATE_MAX)
        for cpu in 0..<Int(numCPUs) {
            let base = cpu * cpuStateCount
            let user = info[base + Int(CPU_STATE_USER)]
            let system = info[base + Int(CPU_STATE_SYSTEM)]
            let idle = info[base + Int(CPU_STATE_IDLE)]
            let nice = info[base + Int(CPU_STATE_NICE)]

            let lastUser = last[base + Int(CPU_STATE_USER)]
            let lastSystem = last[base + Int(CPU_STATE_SYSTEM)]
            let lastIdle = last[base + Int(CPU_STATE_IDLE)]
            let lastNice = last[base + Int(CPU_STATE_NICE)]

            let total = user + system + idle + nice
            let lastTotal = lastUser + lastSystem + lastIdle + lastNice
            let deltaTotal = total > lastTotal ? total - lastTotal : 0
            let deltaIdle = idle > lastIdle ? idle - lastIdle : 0

            totalTicks += Double(deltaTotal)
            usedTicks += Double(deltaTotal - deltaIdle)
        }

        lastCPUSample = info
        guard totalTicks > 0 else { return nil }
        return (usedTicks / totalTicks) * 100.0
    }

    func memoryUsagePercent() -> (percent: Double, usedBytes: UInt64, totalBytes: UInt64, cachedBytes: UInt64)? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count)
        let wired = UInt64(stats.wire_count)
        let compressed = UInt64(stats.compressor_page_count)
        let inactive = UInt64(stats.inactive_count)
        // Align with Activity Monitor "Memory Used": active + wired + compressed
        let usedPages = active + wired + compressed
        let cachedPages = inactive
        let usedBytes = usedPages * pageSize
        let cachedBytes = cachedPages * pageSize
        let totalBytes = ProcessInfo.processInfo.physicalMemory
        guard totalBytes > 0 else { return nil }
        let percent = (Double(usedBytes) / Double(totalBytes)) * 100.0
        return (percent, usedBytes, totalBytes, cachedBytes)
    }

    func networkThroughput() -> (downBps: Double, upBps: Double, totalBps: Double)? {
        guard let totals = getNetworkBytes() else { return nil }
        let now = Date().timeIntervalSince1970

        defer {
            lastNetworkSample = (bytesIn: totals.bytesIn, bytesOut: totals.bytesOut, timestamp: now)
        }

        guard let last = lastNetworkSample else {
            return nil
        }

        let deltaTime = now - last.timestamp
        guard deltaTime > 0 else { return nil }

        let deltaIn = totals.bytesIn >= last.bytesIn ? totals.bytesIn - last.bytesIn : 0
        let deltaOut = totals.bytesOut >= last.bytesOut ? totals.bytesOut - last.bytesOut : 0

        let downBps = Double(deltaIn) / deltaTime
        let upBps = Double(deltaOut) / deltaTime
        return (downBps, upBps, downBps + upBps)
    }

    func diskThroughputMBps() async -> Double? {
        if let iokitValue = diskThroughputFromIOKit() {
            return iokitValue
        }
        return await diskThroughputFromIostat()
    }

    private func diskThroughputFromIOKit() -> Double? {
        guard let totals = getDiskBytes() else { return nil }
        let now = Date().timeIntervalSince1970
        defer {
            lastDiskSample = (readBytes: totals.readBytes, writeBytes: totals.writeBytes, timestamp: now)
        }
        guard let last = lastDiskSample else { return nil }
        let deltaTime = now - last.timestamp
        guard deltaTime > 0 else { return nil }
        let deltaRead = totals.readBytes >= last.readBytes ? totals.readBytes - last.readBytes : 0
        let deltaWrite = totals.writeBytes >= last.writeBytes ? totals.writeBytes - last.writeBytes : 0
        let mbPerSecond = Double(deltaRead + deltaWrite) / deltaTime / 1_048_576
        return mbPerSecond
    }

    private func diskThroughputFromIostat() async -> Double? {
        do {
            let cmd = "LC_ALL=C iostat -d -w 1 -c 2 | awk '/^disk/{sum+$(NF)} END{print sum}'"
            let output = try await shell.run(cmd, timeout: 3)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(trimmed)
        } catch {
            return nil
        }
    }

    private func getDiskBytes() -> (readBytes: UInt64, writeBytes: UInt64)? {
        let matching = IOServiceMatching("IOBlockStorageDriver")
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0

        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }

            if let stats = IORegistryEntryCreateCFProperty(service, "Statistics" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? [String: Any] {
                if let read = stats["Bytes (Read)"] as? UInt64 {
                    totalRead += read
                } else if let readNum = stats["Bytes (Read)"] as? NSNumber {
                    totalRead += readNum.uint64Value
                }
                if let write = stats["Bytes (Written)"] as? UInt64 {
                    totalWrite += write
                } else if let writeNum = stats["Bytes (Written)"] as? NSNumber {
                    totalWrite += writeNum.uint64Value
                }
            }
        }

        return (totalRead, totalWrite)
    }

    private func getNetworkBytes() -> (bytesIn: UInt64, bytesOut: UInt64)? {
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let first = addressPointer else {
            return nil
        }
        defer { freeifaddrs(addressPointer) }

        var bytesIn: UInt64 = 0
        var bytesOut: UInt64 = 0
        var pointer = first
        while true {
            let flags = Int32(pointer.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0

            if isUp && !isLoopback, let data = pointer.pointee.ifa_data,
               pointer.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) {
                let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                bytesIn += UInt64(ifData.ifi_ibytes)
                bytesOut += UInt64(ifData.ifi_obytes)
            }

            guard let next = pointer.pointee.ifa_next else { break }
            pointer = next
        }

        return (bytesIn, bytesOut)
    }

}

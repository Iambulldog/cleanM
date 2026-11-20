import Darwin
import Foundation

/// Samples CPU, memory, disk and network statistics using Mach / BSD APIs.
final class SystemMonitorService {
    private var previousCPUTicks: [[UInt32]] = []
    private var previousInterfaceBytes: [String: (rx: UInt32, tx: UInt32)] = [:]
    private var previousSampleTime: Date?
    private var cumulativeRx: UInt64 = 0
    private var cumulativeTx: UInt64 = 0

    func sample() -> SystemStats {
        let now = Date()
        var stats = SystemStats()
        stats.timestamp = now

        let cores = sampleCPU()
        stats.cpuPerCore = cores
        stats.cpuTotal = cores.isEmpty ? 0 : cores.reduce(0, +) / Double(cores.count)
        stats.memory = Self.sampleMemory()
        stats.disk = Self.sampleDisk()
        stats.network = sampleNetwork(now: now)
        previousSampleTime = now
        return stats
    }

    // MARK: CPU

    private func sampleCPU() -> [Double] {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard kr == KERN_SUCCESS, let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_,
                          vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }

        let stateMax = Int(CPU_STATE_MAX)
        var current: [[UInt32]] = []
        current.reserveCapacity(Int(cpuCount))
        for cpu in 0..<Int(cpuCount) {
            let base = cpu * stateMax
            current.append([
                UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)]),
                UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]),
            ])
        }

        defer { previousCPUTicks = current }
        guard previousCPUTicks.count == current.count else {
            return Array(repeating: 0, count: current.count)
        }

        return zip(current, previousCPUTicks).map { now, before in
            let user = Double(now[0] &- before[0])
            let system = Double(now[1] &- before[1])
            let idle = Double(now[2] &- before[2])
            let nice = Double(now[3] &- before[3])
            let total = user + system + idle + nice
            return total > 0 ? min(1, (user + system + nice) / total) : 0
        }
    }

    // MARK: Memory

    static func sampleMemory() -> MemoryStats {
        var stats = MemoryStats()
        stats.total = sysctlUInt64("hw.memsize")

        var vm = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let page = UInt64(vm_kernel_page_size)
            let internalPages = UInt64(vm.internal_page_count)
            let purgeable = UInt64(vm.purgeable_count)
            stats.appMemory = (internalPages > purgeable ? internalPages - purgeable : 0) * page
            stats.wired = UInt64(vm.wire_count) * page
            stats.compressed = UInt64(vm.compressor_page_count) * page
            stats.cached = (UInt64(vm.external_page_count) + purgeable) * page
            stats.free = UInt64(vm.free_count) * page
            stats.used = min(stats.total, stats.appMemory + stats.wired + stats.compressed)
        }

        var level: Int32 = 1
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 {
            stats.pressure = MemoryPressure(rawValue: Int(level)) ?? .normal
        }
        return stats
    }

    private static func sysctlUInt64(_ name: String) -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : 0
    }

    // MARK: Disk

    static func sampleDisk() -> DiskStats {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        guard let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey,
                                                             .volumeTotalCapacityKey]) else { return DiskStats() }
        return DiskStats(total: Int64(values.volumeTotalCapacity ?? 0),
                         available: values.volumeAvailableCapacityForImportantUsage ?? 0)
    }

    // MARK: Network

    private func sampleNetwork(now: Date) -> NetworkStats {
        var current: [String: (rx: UInt32, tx: UInt32)] = [:]
        var addrs: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&addrs) == 0, let first = addrs {
            var cursor: UnsafeMutablePointer<ifaddrs>? = first
            while let ifa = cursor {
                defer { cursor = ifa.pointee.ifa_next }
                guard let addr = ifa.pointee.ifa_addr,
                      addr.pointee.sa_family == UInt8(AF_LINK),
                      let data = ifa.pointee.ifa_data else { continue }
                let name = String(cString: ifa.pointee.ifa_name)
                if name.hasPrefix("lo") { continue }
                let ifData = data.assumingMemoryBound(to: if_data.self).pointee
                current[name] = (ifData.ifi_ibytes, ifData.ifi_obytes)
            }
            freeifaddrs(first)
        }

        var deltaRx: UInt64 = 0
        var deltaTx: UInt64 = 0
        for (name, value) in current {
            guard let before = previousInterfaceBytes[name] else { continue }
            // 32-bit counters wrap; wrapping subtraction gives the right delta across one wrap.
            deltaRx += UInt64(value.rx &- before.rx)
            deltaTx += UInt64(value.tx &- before.tx)
        }
        previousInterfaceBytes = current
        cumulativeRx &+= deltaRx
        cumulativeTx &+= deltaTx

        var result = NetworkStats(totalReceived: cumulativeRx, totalSent: cumulativeTx)
        if let previous = previousSampleTime {
            let elapsed = now.timeIntervalSince(previous)
            if elapsed > 0 {
                result.downloadPerSecond = Double(deltaRx) / elapsed
                result.uploadPerSecond = Double(deltaTx) / elapsed
            }
        }
        return result
    }
}

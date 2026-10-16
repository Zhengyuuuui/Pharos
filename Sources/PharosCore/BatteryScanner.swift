import Foundation
import IOKit
import IOKit.ps

/// Live scanner for macOS battery, power adapter, and hardware charging capabilities.
/// Reads from IOKit and AppleSmartBattery with zero background overhead.
public enum BatteryScanner {
    /// Probes available SMC hardware registers for battery charging control.
    public static func probeCapabilities(smc: SMCClient? = SMCClient()) -> BatteryHardwareCapabilities {
        guard let smc else {
            return BatteryHardwareCapabilities()
        }
        return BatteryHardwareCapabilities(
            hasCHTE: smc.exists("CHTE"),
            hasCH0C: smc.exists("CH0C"),
            hasCHIE: smc.exists("CHIE"),
            hasCH0J: smc.exists("CH0J"),
            hasACLC: smc.exists("ACLC")
        )
    }

    /// Reads live battery telemetry from IOKit and AppleSmartBattery.
    public static func read() -> BatteryReading? {
        var reading = BatteryReading()

        // 1. Read IOPS power sources info
        if let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] {
            for src in sources {
                guard let desc = IOPSGetPowerSourceDescription(snapshot, src)?.takeUnretainedValue() as? [String: Any] else {
                    continue
                }
                if let type = desc[kIOPSTransportTypeKey] as? String, type == kIOPSInternalType {
                    if let cur = desc[kIOPSCurrentCapacityKey] as? Int { reading.currentPercent = cur }
                    if let max = desc[kIOPSMaxCapacityKey] as? Int { reading.maxCapacity = max }
                    if let isChg = desc[kIOPSIsChargingKey] as? Bool { reading.isCharging = isChg }
                    if let isDone = desc[kIOPSIsChargedKey] as? Bool { reading.isCharged = isDone }
                    if let state = desc[kIOPSPowerSourceStateKey] as? String {
                        reading.powerSource = PowerSourceState.from(raw: state)
                    }
                    if let time = desc[kIOPSTimeToFullChargeKey] as? Int, time > 0 {
                        reading.timeRemainingMinutes = time
                    } else if let time = desc[kIOPSTimeToEmptyKey] as? Int, time > 0 {
                        reading.timeRemainingMinutes = time
                    }
                    if let health = desc[kIOPSBatteryHealthKey] as? String {
                        reading.health = BatteryHealth.from(raw: health)
                    }
                    if let opt = desc["Optimized Battery Charging Engaged"] as? Int {
                        reading.optimizedChargingEngaged = (opt != 0)
                    }
                }
            }
        }

        // 2. Read AppleSmartBattery from IOKit registry
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            defer { IOObjectRelease(service) }
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] {
                
                if let rawCurrent = dict["AppleRawCurrentCapacity"] as? Int {
                    reading.remainingCapacity = rawCurrent
                } else if let cur = dict["CurrentCapacity"] as? Int {
                    reading.remainingCapacity = cur
                }

                if let rawMax = dict["AppleRawMaxCapacity"] as? Int {
                    reading.maxCapacity = rawMax
                }

                if let design = dict["DesignCapacity"] as? Int, design > 0 {
                    reading.designCapacity = design
                    reading.healthPercent = Swift.min(100, Swift.max(0, reading.maxCapacity * 100 / design))
                }

                if let cycles = dict["CycleCount"] as? Int {
                    reading.cycleCount = cycles
                }

                if let tempRaw = dict["Temperature"] as? Int {
                    // Apple reports temperature in tenths of a Kelvin (e.g. 3054 = 305.4 K)
                    let kelvin = Double(tempRaw) / 10.0
                    reading.temperatureCelsius = Swift.max(0.0, kelvin - 273.15)
                }

                if let amp = dict["Amperage"] as? Int {
                    reading.amperage = amp
                }

                if let volt = dict["Voltage"] as? Int {
                    reading.voltage = Double(volt) / 1000.0 // mV to V
                }

                reading.watts = abs(Double(reading.amperage) * reading.voltage / 1000.0)

                if let isChg = dict["IsCharging"] as? Bool {
                    reading.isCharging = isChg
                }

                if let isFull = dict["FullyCharged"] as? Bool {
                    reading.isCharged = isFull
                }

                if let extConnected = dict["ExternalConnected"] as? Bool, extConnected {
                    reading.powerSource = .acPower
                }

                if let adapter = dict["AdapterDetails"] as? [String: Any] {
                    if let watts = adapter["Watts"] as? Int {
                        reading.adapterWatts = watts
                    }
                    if let name = adapter["Name"] as? String {
                        reading.adapterName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    } else if let desc = adapter["Description"] as? String {
                        reading.adapterName = desc.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
        }

        return reading
    }
}

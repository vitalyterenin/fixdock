import Dispatch
import Foundation
import XPC

enum ProbeError: Error, CustomStringConvertible {
    case invalidArguments(String)
    case missingApplyFlag

    var description: String {
        switch self {
        case .invalidArguments(let message):
            message
        case .missingApplyFlag:
            "Команды смены display требуют явный флаг --apply"
        }
    }
}

struct Arguments {
    var apply = false
    var targetDisplayID: UInt64?
    var timeout: Double = 2.0
    var help = false

    init(_ rawArguments: [String]) throws {
        var index = 1
        while index < rawArguments.count {
            let argument = rawArguments[index]

            switch argument {
            case "--help", "-h":
                help = true
            case "--apply":
                apply = true
            case "--target-display":
                index += 1
                guard index < rawArguments.count, let value = UInt64(rawArguments[index]) else {
                    throw ProbeError.invalidArguments("--target-display требует числовой CGDirectDisplayID")
                }
                targetDisplayID = value
            case "--timeout":
                index += 1
                guard index < rawArguments.count, let value = Double(rawArguments[index]), value > 0 else {
                    throw ProbeError.invalidArguments("--timeout требует положительное число секунд")
                }
                timeout = value
            default:
                throw ProbeError.invalidArguments("Неизвестный аргумент: \(argument)")
            }

            index += 1
        }
    }
}

struct Probe {
    let name: String
    let type: String
    let targetDisplayKey: String?
}

func printUsage() {
    print("""
    DockSidecarProbe

    Read-only probe:
      swift run DockSidecarProbe

    Guarded write probes:
      swift run DockSidecarProbe --target-display <CGDirectDisplayID> --apply

    Цель: проверить XPC endpoint com.apple.dock.sidecar и внутренние сообщения
    getDockDisplay/requestDockOnDisplay без движения курсора и без перезапуска Dock.
    """)
}

func describe(_ object: xpc_object_t) -> String {
    let rawDescription = xpc_copy_description(object)
    defer {
        free(rawDescription)
    }

    return String(cString: rawDescription)
}

func makeMessage(probe: Probe, targetDisplayID: UInt64?) -> xpc_object_t {
    let message = xpc_dictionary_create(nil, nil, 0)
    xpc_dictionary_set_string(message, "type", probe.type)
    xpc_dictionary_set_string(message, "id", UUID().uuidString)

    if let targetDisplayID, let targetDisplayKey = probe.targetDisplayKey {
        xpc_dictionary_set_uint64(message, targetDisplayKey, targetDisplayID)
    }

    return message
}

func runProbe(_ probe: Probe, targetDisplayID: UInt64?, timeout: Double) {
    let connection = xpc_connection_create_mach_service("com.apple.dock.sidecar", nil, 0)
    let replySemaphore = DispatchSemaphore(value: 0)
    let eventSemaphore = DispatchSemaphore(value: 0)

    xpc_connection_set_event_handler(connection) { event in
        print("event for \(probe.name):")
        print(describe(event))
        eventSemaphore.signal()
    }
    xpc_connection_activate(connection)

    let message = makeMessage(probe: probe, targetDisplayID: targetDisplayID)
    print("sending \(probe.name):")
    print(describe(message))

    xpc_connection_send_message_with_reply(connection, message, DispatchQueue.global()) { reply in
        print("reply for \(probe.name):")
        print(describe(reply))
        replySemaphore.signal()
    }

    let deadline = DispatchTime.now() + timeout
    if replySemaphore.wait(timeout: deadline) == .timedOut {
        print("reply for \(probe.name): timeout after \(timeout)s")
    }

    _ = eventSemaphore.wait(timeout: .now() + 0.2)
    xpc_connection_cancel(connection)
}

func run() throws {
    let arguments = try Arguments(CommandLine.arguments)
    if arguments.help {
        printUsage()
        return
    }

    if arguments.targetDisplayID != nil && !arguments.apply {
        throw ProbeError.missingApplyFlag
    }

    let readOnlyProbes = [
        Probe(name: "getDockDisplay", type: "getDockDisplay", targetDisplayKey: nil)
    ]
    let writeProbes = [
        Probe(name: "requestDockOnDisplay disp", type: "requestDockOnDisplay", targetDisplayKey: "disp"),
        Probe(name: "requestDockOnDisplay display", type: "requestDockOnDisplay", targetDisplayKey: "display"),
        Probe(name: "requestDockOnDisplay displayID", type: "requestDockOnDisplay", targetDisplayKey: "displayID")
    ]

    for probe in readOnlyProbes {
        runProbe(probe, targetDisplayID: nil, timeout: arguments.timeout)
    }

    if let targetDisplayID = arguments.targetDisplayID {
        for probe in writeProbes {
            runProbe(probe, targetDisplayID: targetDisplayID, timeout: arguments.timeout)
        }
    }
}

do {
    try run()
} catch let error as ProbeError {
    fputs("error: \(error.description)\n", stderr)
    exit(2)
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}

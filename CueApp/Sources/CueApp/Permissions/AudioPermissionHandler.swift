import AVFoundation
import OSLog
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum AudioPermissionError: LocalizedError {
    case denied
    case restricted
    case unknown(String)
    case timeout

    public var errorDescription: String? {
        switch self {
        case .denied:
            #if os(iOS)
            return "Microphone access was denied. Please enable it in Settings."
            #elseif os(macOS)
            return "Microphone access was denied. Please enable it in System Settings."
            #endif
        case .restricted:
            return "Microphone access is restricted on this device."
        case .unknown(let message):
            return "Unknown error: \(message)"
        case .timeout:
            return "Timed out waiting for microphone permission"
        }
    }
}

public class AudioPermissionHandler {
    private static let logger = Logger(subsystem: "AudioPermissionHandler", category: "Permissions")
    private static let maxRetries = 3
    private static let retryDelay: UInt64 = 500_000_000 // 0.5 seconds in nanoseconds

    #if os(macOS)
    static func validateMacOSPermission() async throws -> Bool {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(macOS 14.0, *) {
            deviceTypes = [.microphone]
        } else {
            deviceTypes = [.builtInMicrophone]
        }

        let audioSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .audio,
            position: .unspecified
        )

        // If no audio devices are found, return false instead of throwing an error
        guard !audioSession.devices.isEmpty else {
            logger.info("No audio input devices found - skipping microphone permission check")
            return false
        }

        do {
            let device = audioSession.devices[0]
            try device.lockForConfiguration()
            device.unlockForConfiguration()
            return true
        } catch {
            logger.error("Failed to access audio device: \(error.localizedDescription)")
            throw AudioPermissionError.denied
        }
    }

    public static func hasPermission() -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        #if os(macOS)
        if status == .authorized {
            let deviceTypes: [AVCaptureDevice.DeviceType]
            if #available(macOS 14.0, *) {
                deviceTypes = [.microphone]
            } else {
                deviceTypes = [.builtInMicrophone]
            }

            let audioSession = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .audio,
                position: .unspecified
            )
            guard let device = audioSession.devices.first else {
                return false
            }
            do {
                try device.lockForConfiguration()
                device.unlockForConfiguration()
                return true
            } catch {
                return false
            }
        }
        #endif
        return status == .authorized
    }
    #endif

    public static func checkAndRequestPermission() async throws {
        logger.debug("Checking audio permission status...")

        var retryCount = 0
        while retryCount < maxRetries {
            let status = AVCaptureDevice.authorizationStatus(for: .audio)
            logger.debug("Current authorization status: \(status.rawValue)")

            switch status {
            case .authorized:
                #if os(macOS)
                // On macOS, verify we can actually access the microphone
                do {
                    _ = try await validateMacOSPermission()
                    logger.debug("MacOS permission validation successful")
                    return
                } catch {
                    logger.error("MacOS permission validation failed: \(error.localizedDescription)")
                    if retryCount == maxRetries - 1 {
                        throw error
                    }
                }
                #else
                return
                #endif

            case .denied:
                logger.error("Permission denied")
                throw AudioPermissionError.denied

            case .restricted:
                logger.error("Permission restricted")
                throw AudioPermissionError.restricted

            case .notDetermined:
                logger.debug("Requesting permission...")
                let granted = await AVCaptureDevice.requestAccess(for: .audio)
                if granted {
                    logger.debug("Permission granted")
                    // On macOS, continue to next iteration to validate
                    #if os(iOS)
                    return
                    #endif
                } else {
                    logger.error("Permission request denied")
                    throw AudioPermissionError.denied
                }

            @unknown default:
                logger.error("Unknown authorization status")
                throw AudioPermissionError.unknown("Unknown authorization status")
            }

            #if os(macOS)
            retryCount += 1
            if retryCount < maxRetries {
                logger.debug("Retrying permission check (attempt \(retryCount + 1)/\(maxRetries))...")
                try await Task.sleep(nanoseconds: retryDelay)
            }
            #endif
        }

        logger.error("Permission check failed after \(maxRetries) attempts")
        throw AudioPermissionError.timeout
    }

    @MainActor public static func openSettings() {
        #if os(iOS)
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(settingsUrl) else {
            return
        }
        UIApplication.shared.open(settingsUrl)
        #elseif os(macOS)
        let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(prefpaneUrl)
        #endif
    }
}

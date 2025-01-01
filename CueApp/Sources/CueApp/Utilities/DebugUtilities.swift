import Foundation

// Helper functions to print thread information
func printThread(_ label: String) {
    let isMain = Thread.isMainThread
    let threadId = pthread_mach_thread_np(pthread_self())
    print("🧵 [\(label)] - Thread: \(threadId), isMain: \(isMain)")
}

// Alternative detailed thread info
func printDetailedThread(_ label: String) {
    let thread = Thread.current
    print("""
    🧵 [\(label)]
    - Thread Name: \(thread.name ?? "unnamed")
    - Thread Number: \(pthread_mach_thread_np(pthread_self()))
    - Is Main: \(Thread.isMainThread)
    - QoS: \(thread.qualityOfService.rawValue)
    ----------------------------------------
    """)
}

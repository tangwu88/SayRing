import Foundation

// Type-check the same Objective-C import and closure wrapping as AppDelegate.
func verifyPolicyInterop(_ method: String, _ arguments: [String: Any], result: @escaping (Any?) -> Void) {
    guard SRActivitySleepCommandAllowed(method, arguments) else { result(nil); return }
    let completion = result
    let result: (Any?) -> Void = { value in completion(SRActivitySleepResult(method, value)) }
    if let permitted = SRActivitySleepEvent("capabilitiesUpdated", arguments) { result(permitted) }
}

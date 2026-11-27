import Foundation
import XCTest

class RunnerTests: XCTestCase {
  func testFirebaseClientConfigurationIsBundledForRunner() throws {
    let bundle = Bundle.main
    let url = try XCTUnwrap(bundle.url(forResource: "GoogleService-Info", withExtension: "plist"))
    let data = try Data(contentsOf: url)
    let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    let configuration = try XCTUnwrap(plist as? [String: Any])

    XCTAssertEqual(configuration["BUNDLE_ID"] as? String, try XCTUnwrap(bundle.bundleIdentifier))
    for key in ["GOOGLE_APP_ID", "PROJECT_ID", "API_KEY", "GCM_SENDER_ID"] {
      let value = try XCTUnwrap(configuration[key] as? String, "Missing \(key)")
      XCTAssertFalse(value.isEmpty, "Empty \(key)")
    }
  }
}

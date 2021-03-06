import Quick
import Nimble
import Analytics
import Alamofire
import Alamofire_Synchronous

// End to End tests require some private credentials, so we can't embed them in source.
// On CI, we inject these values with sed (see circle config for exact command).
let RUN_E2E_TESTS = false
let RUNSCOPE_TOKEN = "{RUNSCOPE_TOKEN}"

func hasMatchingId(messageId: String) -> Bool {
  if !RUN_E2E_TESTS {
    return true
  }
  
  let headers: HTTPHeaders = [
    "Authorization": "Bearer \(RUNSCOPE_TOKEN)",
  ]
  
  // Runscope Bucket for https://www.runscope.com/stream/uh9834m87jz5
  let response = Alamofire.request("https://api.runscope.com/buckets/uh9834m87jz5/messages?count=10", headers: headers).responseJSON()
  for message in (response.result.value as! [String: Any])["data"] as! [[String: Any]] {
    let uuid = message["uuid"] as! String
    
    let response = Alamofire.request("https://api.runscope.com/buckets/uh9834m87jz5/messages/\(uuid)", headers: headers).responseJSON()
    let body = (((response.result.value as! [String: Any])["data"] as! [String: Any])["request"] as! [String: Any])["body"] as! String
    
    if (body.contains("\"properties\":{\"id\":\"\(messageId)\"}")) {
      return true
    }
  }
  
  return false
}

// End to End tests as described in https://paper.dropbox.com/doc/Libraries-End-to-End-Tests-ESEakc3LxFrqcHz69AmyN.
// We connect a webhook destination to a Segment source, send some data to the source using the libray. Then we
// verify that the data was sent to the source by finding it from the Webhook destination.
class AnalyticsE2ETests: QuickSpec {
  override func spec() {
    var analytics: SEGAnalytics!
    
    beforeEach {
      // Write Key for https://app.segment.com/segment-libraries/sources/analytics_ios_e2e_test/overview
      let config = SEGAnalyticsConfiguration(writeKey: "3VxTfPsVOoEOSbbzzbFqVNcYMNu2vjnr")
      config.flushAt = 1
      
      SEGAnalytics.setup(with: config)
      
      analytics = SEGAnalytics.shared()
    }
    
    afterEach {
      analytics.reset()
    }
    
    it("track") {
      let uuid = UUID().uuidString
      self.expectation(forNotification: NSNotification.Name("SegmentRequestDidSucceed"), object: nil, handler: nil)
      
      analytics.track("E2E Test", properties: ["id": uuid])
      
      self.waitForExpectations(timeout: 20)
      
      for _ in 1...5 {
        sleep(2)
        if hasMatchingId(messageId: uuid) {
          return
        }
      }
      
      fail("could not find message with id \(uuid) in Runscope")
    }
  }
}

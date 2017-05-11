//
//  V4SignerTests.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//

import XCTest
@testable import ElasticsearchClient

class V4SignerTests: XCTestCase {
    
    // These AWS credentials have expired or have been deleted, they are valid only for unit testing.
    let accessKey = "AKIAJODU6PESZF6ENZ2A"
    let secretKey = "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"
    let regionName = "eu-central-1"
    let bodyDigest = "96fe862bffd24748621f5e6b1938c3f7a8a18569c82b68dccad1e22b20533440"
    
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    func testAuthorizationHeader() {
        let now = parseDate("20160318T003250Z")
        let url = URL(string: "https://capturedeu.s3-eu-central-1.amazonaws.com/xrQ77e9S")!
        let signer = V4Signer(accessKey: accessKey, secretKey: secretKey, regionName: regionName, serviceName: "s3")
        guard let headers = try? signer.signedHeaders(url: url, bodyDigest: bodyDigest, httpMethod: "PUT", date: now) else {
            XCTFail("Signed headers should have been created")
            return
        }
        
        let expected = "AWS4-HMAC-SHA256 Credential=AKIAJODU6PESZF6ENZ2A/20160318/eu-central-1/s3/aws4_request, SignedHeaders=content-type;host;x-amz-content-sha256;x-amz-date, Signature=65c6d9f660679d93431f50b22eed96f8d50350172d993fcfcd6225816643e43d"
        
        XCTAssertTrue(expected == headers["authorization"], "Authorization header should have been signed properly.")
    }
    
    func parseDate(_ date: String) -> NSDate {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = NSTimeZone(name: "UTC")! as TimeZone
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale!
        return formatter.date(from: date)! as NSDate
    }
}

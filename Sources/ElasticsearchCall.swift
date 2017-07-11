//
//  ElasticsearchCall.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

import Foundation
import Gloss

public enum ElasticsearchCallError: Error {
    case invalidHost(host: URL)
    case invalidPath(path: URL)
    case invalidInitialization(text: String)
    case invalidPostObject(serializationError: Error)
    case noDataReturned
    case indexOrTypeMissing
    case responseIsNotValidJSON(responseText: String)
    case responseIsNotValidSearchResult(json: JSON)
    case invalidQuery(httpStatus: Int, type: String, reason: String, index: String, resourceId: String, resourceType: String)
}

extension ElasticsearchCallError: LocalizedError {
    public var errorDescription: String? {
        return "ElasticsearchCallError \(self)"
    }
}



public class ElasticsearchCall {
    
    // MARK: - Fetching Documents
    
    public static func fetchDocumentSource(typeName: String, id: Int, completion: @escaping ((AsyncResult<JSON>) -> Void)) {
        var suffix = self.suffix(withTypeName: typeName, id: id)
        suffix = suffix.appending("/_source")
        
        self.sendElasticSearchRequest(suffix: suffix, completion: completion)
    }
    
    public static func fetchDocumentHeader (typeName: String, id: Int, completion: @escaping ((AsyncResult<JSON>) -> Void)) {
        let suffix = self.suffix(withTypeName: typeName, id: id)
        
        self.sendElasticSearchRequest(suffix: suffix, completion: completion)
    }
    
    public static func search (indexName: String, typeName: String, query: JSON?, completion: @escaping ((AsyncResult<JSON>) -> Void)) {
        var suffix = self.suffix(withIndexName: indexName, typeName: typeName)
        suffix = suffix.appending("/_search")
        self.sendElasticSearchRequest(suffix: suffix, postJSON: query, completion: completion)
    }
    
    // MARK: - Updating Documents
    
    public static func update (typeName: String, documentId: Int, fields: JSON!, completion: @escaping ((AsyncResult<JSON>) -> Void)) {
        var suffix = self.suffix(withTypeName: typeName)
        suffix = suffix.appending("/\(documentId)")
        suffix = suffix.appending("/_update")
        let updatePost: JSON = ["doc": fields]
        self.sendElasticSearchRequest(suffix: suffix, postJSON: updatePost, completion: completion)
    }
    
}

// MARK: - Building the Request

extension ElasticsearchCall {
    
    fileprivate static func suffix(withTypeName typeName: String, id: Int? = nil) -> String {
        let indexName = ElasticsearchClient.indexName(forTypeName: typeName)
        return self.suffix(withIndexName: indexName, typeName: typeName, id: id)
    }
    
    fileprivate static func suffix(withIndexName indexName: String, typeName: String, id: Int? = nil) -> String {
        var suffix = "/".appending(indexName).appending("/").appending(typeName)
        if let id = id {
            suffix = suffix.appending("/\(id)")
        }
        return suffix
    }
    
    fileprivate static func requestURL(withSuffix suffix: String) -> String {
        var url = ElasticsearchClient.rootURL
        if suffix.utf16.count == 0 {
            return url
        }
        
        if !suffix.hasPrefix("/") {
            url = "\(url)/" as String
        }
        url = "\(url)\(suffix)"
        return url
    }
    
    fileprivate static func createRequest(urlString: String, postJSON: JSON? = nil) throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw ElasticsearchCallError.invalidInitialization(text: "String \"\(urlString)\" doesnt parse to a valid URL.")
        }
        var request = URLRequest(url: url,
                                 cachePolicy: .useProtocolCachePolicy,
                                 timeoutInterval: 10.0)
        
        
        var httpMethod = urlString.hasSuffix("update") ? "POST" : "GET"
        var postString : String? = nil
        var postData : Data? = nil
        
        if let json = postJSON {
            do {
                postData = try JSONSerialization.data(withJSONObject: json)
                postString = String(data:postData!, encoding: .utf8)
                httpMethod = "POST"
                request.httpBody = postData
            }
            catch {
                throw ElasticsearchCallError.invalidPostObject(serializationError: error)
            }
        }
        
        request.httpMethod = httpMethod
        
        if ElasticsearchClient.signatureType == .awsV4 {
            let body = postString ?? ""
            let bodyDigest = V4Signer.getSha256(forString: body)
            
            let signer = try ElasticsearchCall.makeAwsV4Signer()
            let headers = try signer.signedHeaders(url: request.url!, bodyDigest: bodyDigest, httpMethod: httpMethod)
            for (key, value) in headers {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        return request
    }
    
    private static func makeAwsV4Signer() throws -> V4Signer {
        guard let region = ElasticsearchClient.awsRegion,
            let secretKey = ElasticsearchClient.awsSecretKey,
            let accessKey = ElasticsearchClient.awsAccessKey else {
                throw ElasticsearchCallError.invalidInitialization(text: "\(#function) The AWS region, secretKey, and accessKey must be provided.")
        }
        
        return V4Signer(accessKey: accessKey, secretKey: secretKey, regionName: region, serviceName: "es")
    }
}

// MARK: - Sending the Request

extension ElasticsearchCall {
    
    fileprivate static func sendElasticSearchRequest(suffix: String!, postJSON: JSON? = nil, completion: @escaping ((AsyncResult<JSON>) -> Void)) {
        
        let requestURL = self.requestURL(withSuffix: suffix)
        do {
            let request = try self.createRequest(urlString: requestURL, postJSON: postJSON)
            let call = ElasticsearchCall()
            call.sendRequest(request: request, completion: completion)
        }
        catch {
            completion(AsyncResult<JSON> { throw error } )
        }
    }
    
    private func sendRequest(request: URLRequest, completion: ( @escaping (AsyncResult<Data>) -> Void)) {
        let session = URLSession.shared
        let dataTask = session.dataTask(with: request, completionHandler: { (data, response, error) -> Void in
            
            if let httpResponse = response as? HTTPURLResponse,
                let url = httpResponse.url?.absoluteString {
                let code = httpResponse.statusCode
                logger.log("ElasticsearchCall HTTP \(code) returned for \(url)")
            }
            
            completion(AsyncResult {
                if let error = error { throw error }
                guard let data = data else { throw ElasticsearchCallError.noDataReturned }
                return data
            })
        })
        
        dataTask.resume()
    }
    
    private func sendRequest(request: URLRequest, completion:( @escaping (AsyncResult<JSON>) -> Void)) {
        self.sendRequest(request: request) { (asyncResult: AsyncResult<Data>) in
            
            let resultJSON = asyncResult.flatMap({ data -> AsyncResult<JSON> in
                return AsyncResult { try self.parseResponse(data) }
            })
            completion(resultJSON)
        }
    }
    
    private func parseResponse(_ response: Data) throws -> JSON {
        var json: JSON?
        
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: response)
            json = jsonObject as? JSON
            
            if json == nil {
                throw ElasticsearchCallError.responseIsNotValidJSON(responseText: "")
            }
        }
        catch {
            let text = String(data: response, encoding: .utf8) ?? "-response cant be decoded to text-"
            throw ElasticsearchCallError.responseIsNotValidJSON(responseText: text)
        }
        
        let parsedJson = json!
        
        if parsedJson.keys.count == 2,
            let status = parsedJson["status"] as? Int,
            let error = parsedJson["error"] as? JSON {
            
            let errorType = error["type"] as? String ?? "-error type unknown-"
            let errorReason = error["reason"] as? String ?? "-error reason unknown"
            let errorIndex = error["index"] as? String ?? "-error index unknown"
            let errorResourceId = error["resource.id"] as? String ?? "-error reaource.id unknown"
            let errorResourceType = error["resource.type"] as? String ?? "-error reaource.type unknown"
            
            throw ElasticsearchCallError.invalidQuery(httpStatus: status, type: errorType, reason: errorReason, index: errorIndex, resourceId: errorResourceId, resourceType: errorResourceType)
        }
        
        return parsedJson
    }
}


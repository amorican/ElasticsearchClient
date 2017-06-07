//
//  ElasticsearchAsyncResult.swift
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

public typealias AsyncResult<T> = ElasticsearchAsyncResult<T>

public enum ElasticsearchAsyncResult<T> {
    case success(T)
    case failure(Error)
}

extension ElasticsearchAsyncResult {
    func map<U>(_ function: (T) -> U) -> ElasticsearchAsyncResult<U> {
        switch self {
        case .success(let value): return .success(function(value))
        case .failure(let error): return .failure(error)
        }
    }
    
    func flatMap<U>(_ function: (T) -> ElasticsearchAsyncResult<U>) -> ElasticsearchAsyncResult<U> {
        switch self {
        case .success(let value): return function(value)
        case .failure(let error): return .failure(error)
        }
    }
}

extension ElasticsearchAsyncResult {
    // Return the value if it is a .success or throw the error if it is a .failure
    public func resolve() throws -> T {
        switch self {
        case ElasticsearchAsyncResult.success(let value): return value
        case ElasticsearchAsyncResult.failure(let error): throw error
        }
    }
    
    // Construct a .success if the expression returns a value or a .failure if it throws
    init(_ throwingExpression: (Void) throws -> T) {
        do {
            let value = try throwingExpression()
            self = ElasticsearchAsyncResult.success(value)
        } catch {
            self = ElasticsearchAsyncResult.failure(error)
        }
    }
}


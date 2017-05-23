//
//  ElasticsearchAsyncResult.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
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


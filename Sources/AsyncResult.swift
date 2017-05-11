//
//  AsyncResult.swift
//  ElasticsearchClient
//
//  Created by Frank Le Grand on 5/11/17.
//
//


import Foundation

enum AsyncResult<T> {
    case success(T)
    case failure(Error)
}

extension AsyncResult {
    func map<U>(_ function: (T) -> U) -> AsyncResult<U> {
        switch self {
        case .success(let value): return .success(function(value))
        case .failure(let error): return .failure(error)
        }
    }
    
    func flatMap<U>(_ function: (T) -> AsyncResult<U>) -> AsyncResult<U> {
        switch self {
        case .success(let value): return function(value)
        case .failure(let error): return .failure(error)
        }
    }
}

extension AsyncResult {
    // Return the value if it is a .success or throw the error if it is a .failure
    func resolve() throws -> T {
        switch self {
        case AsyncResult.success(let value): return value
        case AsyncResult.failure(let error): throw error
        }
    }
    
    // Construct a .success if the expression returns a value or a .failure if it throws
    init(_ throwingExpression: (Void) throws -> T) {
        do {
            let value = try throwingExpression()
            self = AsyncResult.success(value)
        } catch {
            self = AsyncResult.failure(error)
        }
    }
}


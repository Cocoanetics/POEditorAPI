//
//  WebService.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

/// The result of a web service request
public enum WebServiceResult<T>
{
	/// The result is deemed successful, the result is attached
	case success(T)
	
	/// The result is deemed a failure, the error is attached
	case failure(Error)
}

public enum WebServiceError: Error
{
	case networkError(Error)
	case serviceError(String)
	case unexpectedResponse(String)
}

/// The completion handler of a web service request
public typealias WebServiceCompletionHandler<T> = (WebServiceResult<T>)->()

/// A web service exposing an endpoint with functions that can be called
public protocol WebService
{
	/// the endpoint URL of the receiver
	var endpoint: URL { get }
	
	/// The session to use for requests
	var session: URLSession  { get }
}

extension WebService
{
	var session: URLSession {
		return URLSession.shared
	}
}

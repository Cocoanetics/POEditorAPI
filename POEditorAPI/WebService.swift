//
//  WebService.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Cocoa

/// The result of a web service request
enum WebServiceResult<T>
{
	/// The result is deemed successful, the result is attached
	case success(T)
	
	/// The result is deemed a failure, the error is attached
	case failure(Error)
}

enum WebServiceError: Error
{
	case networkError(Error)
	case unexpectedResponse(String)
}

/// The completion handler of a web service request
typealias WebServiceCompletionHandler<T> = (WebServiceResult<T>)->()

/// A web service exposing an endpoint with functions that can be called
protocol WebService
{
	/// the endpoint URL of the receiver
	var endpoint: URL { get }
	
	/// The session configuration to use for requests
	var sessionConfiguration: URLSessionConfiguration { get }
}

extension WebService
{
	var sessionConfiguration: URLSessionConfiguration {
		return URLSessionConfiguration.default
	}
	

}

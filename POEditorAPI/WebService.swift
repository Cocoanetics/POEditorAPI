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
	
	private func processResultJSON<T>(object: Any, resultKey: String) throws -> T
	{
		guard let dictionary = object as? JSONDictionary else
		{
			throw WebServiceError.unexpectedResponse("JSON response was not a dictionary")
		}
		
		guard let response = dictionary["response"] as? JSONDictionary else
		{
			throw WebServiceError.unexpectedResponse("JSON response did not contain response dictionary")
		}
		
		if let status = response["status"] as? String, status == "fail"
		{
			let message = response["message"] as? String
			throw WebServiceError.unexpectedResponse(message ?? "Unknown Error")
		}
		
		guard let result = dictionary[resultKey] else
		{
			throw WebServiceError.unexpectedResponse("Could not find '\(resultKey)'")
		}
		
		if let typedResult = result as? T
		{
			return typedResult
		}
		else if let string = result as? String, T.self == URL.self
		{
			// special case where a URL is expected, but the result is a string
			let url = URL(string: string) as! T
			return url
		}
		else
		{
			throw WebServiceError.unexpectedResponse("Unexpected result type")
		}
	}
	
	/// Creates a data task which picks out the correct result from the JSON dictionary
	func responseProcessingDataTask<T>(with request: URLRequest, resultKey: String, completion: WebServiceCompletionHandler<T>?)->URLSessionDataTask
	{
		return URLSession.shared.dataTaskReturningJSON(with: request) { (result) in
			
			do
			{
				switch result
				{
				case .success(let object):
					let typedResult: T =  try self.processResultJSON(object: object, resultKey: resultKey)
					completion?(.success(typedResult))
					
				case .failure(let error):
					throw error
				}
				
			}
			catch let error
			{
				completion?(.failure(error))
			}
		}
	}
}

//
//  URLSession.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

extension URLSession
{
	/// A data task that expects and returns a JSON object
	func dataTaskReturningJSON(with request: URLRequest, completion: WebServiceCompletionHandler<Any>?) -> URLSessionDataTask
	{
		return dataTask(with: request) { (data, response, error) in
			
			do
			{
				/// rethrow a network error
				if let error = error
				{
					throw WebServiceError.networkError(error)
				}

				/// check if there is data and the correct MIME type
				guard let data = data,
						response!.mimeType == "application/json" else
				{
					throw WebServiceError.unexpectedResponse("Unexpected response, MIME type '\(response!.mimeType ?? "NONE")'")
				}
				
				/// deserialize JSON
				let object = try JSONSerialization.jsonObject(with: data)
				completion?(.success(object))
			}
			catch
			{
				completion?(.failure(error))
				return
			}
		}
	}
}

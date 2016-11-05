//
//  URLSession.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

enum WebServiceError: Error
{
	case unexpectedResponse(String)
}

extension URLSession
{
	func dataTaskReturningJSON(with request: URLRequest, completion: WebServiceCompletionHandler<Any>?) -> URLSessionDataTask
	{
		return dataTask(with: request) { (data, response, error) in
			
			do
			{
				if let error = error
				{
					throw error
				}

				guard let data = data, response?.mimeType == "application/json" else
				{
					throw WebServiceError.unexpectedResponse("Unexpected response, MIME type '\(response?.mimeType)'")
				}
				
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

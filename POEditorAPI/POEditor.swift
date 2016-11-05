//
//  POEditor.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Cocoa

typealias JSONDictionary = [String: Any]
typealias JSONArray = [Any]


enum ExportType: String
{
	case po = "po"
	case pot = "pot"
	case mo = "mo"
	case xls = "xls"
	case csv = "csv"
	case resw = "resw"
	case resx = "resx"
	case android_strings = "android_strings"
	case apple_strings = "apple_strings"
	case xliff = "xliff"
	case properties = "properties"
	case key_value_json = "key_value_json"
	case json = "json"
}

class POEditor: WebService
{
	/// Specify API endpoint
	var endpoint = URL(string: "https://poeditor.com/api/")!
	
	/// Specify session config
	var sessionConfiguration: URLSessionConfiguration {
		return URLSessionConfiguration.ephemeral
	}
	
	
	func listProjects(completion: WebServiceCompletionHandler<[JSONDictionary]>?)
	{
		let parameters = ["api_token" : "ea5a73dbeea02e992e36671d437679d9",
		                  "action" : "list_projects"]
		let request = URLRequest.formPost(url: endpoint, fields: parameters)
		
		responseProcessingDataTask(with: request, resultKey: "list", completion: completion).resume()
	}
	
	func listProjectLanguages(projectID: Int, completion: WebServiceCompletionHandler<[JSONDictionary]>?)
	{
		let parameters = ["api_token" : "ea5a73dbeea02e992e36671d437679d9",
		                  "action" : "list_languages",
		                  "id": projectID] as [String : Any]
		
		let request = URLRequest.formPost(url: endpoint, fields: parameters)
		
		responseProcessingDataTask(with: request, resultKey: "list", completion: completion).resume()
	}
	
	func exportProjectTranslation(projectID: Int, languageCode: String, type: ExportType, completion: WebServiceCompletionHandler<URL>?)
	{
		let parameters = ["api_token" : "ea5a73dbeea02e992e36671d437679d9",
		                  "action" : "export",
		                  "id": projectID,
		                  "language": languageCode,
		                  "type": type] as [String : Any]
		
		let request = URLRequest.formPost(url: endpoint, fields: parameters)
		
		responseProcessingDataTask(with: request, resultKey: "item", completion: completion).resume()
	}
	
	func processResultJSON(object: Any, resultKey: String) throws -> Any
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
		
		return result
	}
	
	
	func responseProcessingDataTask<T>(with request: URLRequest, resultKey: String, completion: WebServiceCompletionHandler<T>?)->URLSessionDataTask
	{
		return URLSession.shared.dataTaskReturningJSON(with: request) { (result) in
			
			do
			{
				switch result
				{
					case .success(let object):
					
						let result = try self.processResultJSON(object: object, resultKey: resultKey)
					
						if let typedResult = result as? T
						{
							completion?(.success(typedResult))
						}
						else if let string = result as? String, T.self == URL.self
						{
							let url = URL(string: string) as! T
							completion?(.success(url))
						}
						else
						{
							throw WebServiceError.unexpectedResponse("Unexpected result type")
						}
					
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

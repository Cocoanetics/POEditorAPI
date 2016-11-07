//
//  POEditor.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

typealias JSONDictionary = [String: Any]

/// The types of file that translations can be exported in
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
	// MARK: - Properties
	/// Specify API endpoint
	var endpoint = URL(string: "https://poeditor.com/api/")!
	
	/// Specify ephemeral URL session
	lazy var session = {
		return URLSession(configuration: .ephemeral)
	}()
	
	/// API Token to pass with all requests
	var token: String //= "ea5a73dbeea02e992e36671d437679d9";
	
	required init(token: String)
	{
		self.token = token
	}
	
	// MARK: - Public Interface
	
	/// List projects
	func listProjects(completion: WebServiceCompletionHandler<[JSONDictionary]>?)
	{
		let parameters = ["api_token" : token,
		                  "action" : "list_projects"] as [String : Any]
		
		let request = URLRequest.formPost(url: endpoint, fields: parameters)
		
		responseProcessingDataTask(with: request, resultKey: "list", completion: completion).resume()
	}
	
	/// Create a new project
	func createProject(name: String, completion: WebServiceCompletionHandler<Int>?)
	{
		let parameters = ["api_token" : token,
		                  "action" : "create_project",
		                  "name": name] as [String : Any]

		let request = URLRequest.formPost(url: endpoint, fields: parameters)
		
		// note: API is inconsistent, the new project's ID is part of the reponse returned
		
		responseProcessingDataTask(with: request, resultKey: "item", completion: completion).resume()
	}
	
	/// List langauges of specific project
	func listProjectLanguages(projectID: Int, completion: WebServiceCompletionHandler<[JSONDictionary]>?)
	{
		let parameters = ["api_token" : token,
		                  "action" : "list_languages",
		                  "id": projectID] as [String : Any]
		
		let request = URLRequest.formPost(url: endpoint, fields: parameters)
		
		responseProcessingDataTask(with: request, resultKey: "list", completion: completion).resume()
	}
	
	/// Expert project translations into a file
	func exportProjectTranslation(projectID: Int, languageCode: String, type: ExportType, completion: WebServiceCompletionHandler<URL>?)
	{
		let parameters = ["api_token" : token,
		                  "action" : "export",
		                  "id": projectID,
		                  "language": languageCode,
		                  "type": type] as [String : Any]
		
		let request = URLRequest.formPost(url: endpoint, fields: parameters)
		
		responseProcessingDataTask(with: request, resultKey: "item", completion: completion).resume()
	}
	
	// MARK: - Response Processing
	
	/// Processes the JSON dictionary, expecting a certain type under the resultKey
	private func processResultJSON<T>(dictionary: JSONDictionary, resultKey: String) throws -> T
	{
		/// POEditor returns status in response key
		guard let response = dictionary["response"] as? JSONDictionary else
		{
			throw WebServiceError.unexpectedResponse("JSON response did not contain response dictionary")
		}
		
		if let status = response["status"] as? String, status == "fail"
		{
			let message = response["message"] as? String
			throw WebServiceError.serviceError(message ?? "Unknown Error")
		}

		guard let result = dictionary[resultKey] ?? response[resultKey] else
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
	private func responseProcessingDataTask<T>(with request: URLRequest, resultKey: String, completion: WebServiceCompletionHandler<T>?)->URLSessionDataTask
	{
		return session.dataTaskReturningJSON(with: request) { (result) in
			
			do
			{
				switch result
				{
					case .success(let object):
					
						// we expect a dictionary as response
						guard let dictionary = object as? JSONDictionary else
						{
							throw WebServiceError.unexpectedResponse("JSON response is not a dictionary")
						}
					
						// the value at the given key needs to be the expected type
						let typedResult: T = try self.processResultJSON(dictionary: dictionary, resultKey: resultKey)
					
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

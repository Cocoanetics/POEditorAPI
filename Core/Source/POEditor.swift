//
//  POEditor.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

public typealias JSONDictionary = [String: Any]

/// A class representing an API to POEditor.com.
public final class POEditor: WebService
{
	/// The types of file that translations can be exported in
	public enum ExportFileType: String
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

	// MARK: - Properties
	/// Specify API endpoint
	public let endpoint = URL(string: "https://api.poeditor.com/v2/")!

	/// Specify ephemeral URL session
	public lazy var session = {
		return URLSession(configuration: .ephemeral)
	}()

	/// API Token to pass with all requests
	let token: String

	required public init(token: String)
	{
		self.token = token
	}

	// MARK: - Public Interface

	/// List projects on POEditor.com
	/// - parameter completion: The completion block receiving an array of dictionaries each describing a project on POEditor.com if successful.
	public func listProjects(completion: WebServiceCompletionHandler<[JSONDictionary]>?)
	{
		let parameters = ["api_token" : token] as [String : Any]

		let path = endpoint.appendingPathComponent("projects/list")
		let request = URLRequest.formPost(url: path, fields: parameters)

		responseProcessingDataTask(with: request, resultKey: "projects", completion: completion).resume()
	}

	/// Create a new project on POEditor.com
	/// - parameter completion: The completion block receiving Int with the project identifier if successful.
	public func createProject(name: String, completion: WebServiceCompletionHandler<Int>?)
	{
		let parameters = ["api_token" : token,
		                  "name": name] as [String : Any]

		let path = endpoint.appendingPathComponent("projects/add")
		let request = URLRequest.formPost(url: path, fields: parameters)

		// note: API is inconsistent, the new project's ID is part of the reponse returned

		responseProcessingDataTask(with: request, resultKey: "project", completion: completion).resume()
	}

	/// List languages of specific project
	/// - parameter projectID: The project identifier
	/// - parameter completion: The completion block receiving an array of dictionaries each describing a language of the project on POEditor.com if successful.
	public func listProjectLanguages(projectID: Int, completion: WebServiceCompletionHandler<[JSONDictionary]>?)
	{
		let parameters = ["api_token" : token,
		                  "id": projectID] as [String : Any]

		let path = endpoint.appendingPathComponent("languages/list")
		let request = URLRequest.formPost(url: path, fields: parameters)

		responseProcessingDataTask(with: request, resultKey: "languages", completion: completion).resume()
	}

	/// Expert project translations into a file. The URL to the file is provided in the completion handler and you need to download it.
	/// - parameter projectID: The project identifier
	/// - parameter languageCode: The language code to export
	/// - parameter type: The file type to generate
	/// - parameter completion: The completion block receiving an URL for the exported file if successful.
	public func exportProjectTranslation(projectID: Int, languageCode: String, type: ExportFileType, completion: WebServiceCompletionHandler<URL>?)
	{
		let parameters = ["api_token" : token,
		                  "id": projectID,
		                  "language": languageCode,
		                  "type": type] as [String : Any]

		let path = endpoint.appendingPathComponent("projects/export")
		let request = URLRequest.formPost(url: path, fields: parameters)

		responseProcessingDataTask(with: request, resultKey: "url", completion: completion).resume()
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

		guard let resultDict = dictionary["result"] as? JSONDictionary else
		{
			throw WebServiceError.unexpectedResponse("JSON response did not contain result dictionary")
		}

		guard let result = resultDict[resultKey] else
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

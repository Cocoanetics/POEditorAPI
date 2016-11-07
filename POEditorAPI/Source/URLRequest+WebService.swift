//
//  URLRequest.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

extension URLRequest
{
	static func formPost(url: URL, fields: [String: Any]) -> URLRequest
	{
		var request = URLRequest.init(url: url, timeoutInterval: 10.0)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		
		// URL-encode form fields
		var components = URLComponents()
		
		components.queryItems = fields.map { (key, value) -> URLQueryItem in
			return URLQueryItem(name: key, value: "\(value)")
		}
		
		// create form post data and length
		let data = components.url!.query!.data(using: .utf8)!
		request.httpBody = data
		request.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
		
		return request
	}
}

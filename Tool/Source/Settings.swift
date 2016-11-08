//
//  Settings.swift
//  POET
//
//  Created by Oliver Drobnik on 08.11.16.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

/// The project settings for POET
struct Settings
{
	/// The POEditor API Token
	var token: String!
	{
		didSet
		{
			isDirty = true
		}
	}
	
	/// The project ID
	var projectID: Int!
	{
		didSet
		{
			isDirty = true
		}
	}
	
	/// The language codes to export
	var languages: [String]!
	{
		didSet
		{
			isDirty = true
		}
	}
	
	/// The path relative to the CWD where exporting outputs to
	var outputFolder: String?
	{
		didSet
		{
			isDirty = true
		}
	}

	/// Keeps track of modifications
	var isDirty = false
	
	init()
	{
		// try loading if there are settings
		load()
	}
	
	/// Load the settings from the current working directory
	mutating func load()
	{
		let workingDirURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
		let settingsFileURL = workingDirURL.appendingPathComponent("poet.json")
		
		do
		{
			let data = try Data(contentsOf: settingsFileURL)
			
			if let settings = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
			{
				token = settings["token"] as? String
				projectID = settings["projectID"] as? Int
				languages = settings["languages"] as? [String]
				outputFolder = settings["outputFolder"] as? String
			}
		}
		catch _
		{
			
		}
		
		isDirty = false
	}
	
	/// Saves the settings in the current working directory
	mutating func save() throws
	{
		let workingDirURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
		let settingsFileURL = workingDirURL.appendingPathComponent("poet.json")

		var dict = ["token": token,
		            "projectID": projectID,
		            "languages": languages] as [String : Any]
		
		dict["outputFolder"] = outputFolder
		
		let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
		try data.write(to: settingsFileURL)
		
		isDirty = false
	}
}

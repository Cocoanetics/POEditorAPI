//
//  main.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

let sema = DispatchSemaphore(value: 0)

var token: String!
var projectID: Int!
var languages: [String]!

let workingDirURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let settingsFileURL = workingDirURL.appendingPathComponent("poet.json")
var settingsNeedSaving = false

do
{
	let data = try Data(contentsOf: settingsFileURL)

	if let settings = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
	{
		token = settings["token"] as? String
		projectID = settings["projectID"] as? Int
		languages = settings["languages"] as? [String]
	}
}
catch _
{
	
}

// get token from user if needed
if token == nil
{
	// no api token
	print("Enter POEditor API Token> ", terminator: "")
	token = readLine(strippingNewline: true)
	settingsNeedSaving = true
}


let poeditor = POEditor(token: token)

if projectID == nil
{
	var availableProjects: [JSONDictionary]!
	
	poeditor.listProjects { result in
		
		switch result
		{
		case .success(let projects):
			availableProjects = projects
			
		case .failure(WebServiceError.serviceError(let message)):
			print("POEditor.com responded: \(message)")
			exit(1)
			break
			
		case .failure(WebServiceError.networkError(let error)):
			print("Network Error: \(error.localizedDescription)")
			exit(1)
			break
			
		case .failure(let error):
			print(error.localizedDescription)
			break
		}
		
		sema.signal()
	}
	
	sema.wait()
	
	if availableProjects == nil || availableProjects.count == 0
	{
		print("No projects found.")
		exit(1)
	}
	
	print("\nProjects Available")
	print("==================")
	
	for (index, project) in availableProjects.enumerated()
	{
		guard let projectID = project["id"] as? String,
			let projectName = project["name"] as? String else
		{
			continue
		}
		
		let indexStr = String(format: "%3d", index+1)
		print("\t" + indexStr + ".\t" + projectName)
	}
	
	print("\nSelect project to setup> ", terminator: "")
	
	if let string = readLine(strippingNewline: true),
		let number = Int(string)
	{
		let project = availableProjects[number-1]
		projectID = Int((project["id"] as! String))
		settingsNeedSaving = true
	}
	else
	{
		print("No project selected, aborting.")
		exit(1)
	}
}

if languages == nil
{
	var projectLanguages: [JSONDictionary]!
	
	poeditor.listProjectLanguages(projectID: projectID) { result in
		
		switch result
		{
		case .success(let languages):
			projectLanguages = languages
			
		case .failure(WebServiceError.serviceError(let message)):
			print("POEditor.com responded: \(message)")
			exit(1)
			break
			
		case .failure(WebServiceError.networkError(let error)):
			print("Network Error: \(error.localizedDescription)")
			exit(1)
			break
			
		case .failure(let error):
			print(error.localizedDescription)
			break
		}
		
		sema.signal()
	}
	
	sema.wait()
	
	let completeLangs = projectLanguages.filter { (language) -> Bool in
		if let percent = language["percentage"] as? Int, percent == 100
		{
			return true
		}
		
		return false
	}
	
	let languageCodes = completeLangs.map { (language) -> String in
		return language["code"] as! String
	}
	
	languages = languageCodes
	settingsNeedSaving = true
}

// save project settings

if settingsNeedSaving
{
	do
	{
		let dict = ["token": token, "projectID": projectID, "languages": languages] as [String : Any]
		let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
		try data.write(to: settingsFileURL)
		
		print("Project settings aved in " + settingsFileURL.path)
	}
	catch let error
	{
		print(error)
		exit(1)
	}
	
	print("Setup complete. You may edit the config file poet.json to change the imported languages.\n")
}

let exportFolderURL = workingDirURL.appendingPathComponent("POEditor", isDirectory: true)

let fileManager = FileManager.default

for code in languages.sorted()
{
	print("Exporting " + code + "...", terminator:"")
	
	var xcode = code
	
	if xcode == "zh-CN"
	{
		xcode = "zh-Hans"
	}
	else if xcode == "zh-TW"
	{
		xcode = "zh-Hant"
	}
	else if xcode == "en-us"
	{
		xcode = "en"
	}
	else if xcode == "pt-br"
	{
		xcode = "pt-BR"
	}

	let outputFileURL = exportFolderURL.appendingPathComponent(xcode + ".json")
	let outputFolderURL = exportFolderURL.appendingPathComponent(xcode + ".lproj", isDirectory: true)
	
	do
	{
		if !fileManager.fileExists(atPath: exportFolderURL.path)
		{
			try fileManager.createDirectory(at: outputFolderURL, withIntermediateDirectories: true, attributes: nil)
		}
	}
	catch let error
	{
		print("Unable to create output folder " + outputFolderURL.path)
		exit(1)
	}
	
	var exportError: Error?
	
	poeditor.exportProjectTranslation(projectID: projectID, languageCode: code, type: .json) { (result) in
		
		switch result
		{
			case .success(let url):
				
				do
				{
					let data = try Data(contentsOf: url)
					//try data.write(to: outputFileURL)
					
					// code json
					let translations = try JSONSerialization.jsonObject(with: data, options: []) as? [JSONDictionary]
					
					var contexts = [String: [Translation]]()
					
					for translation in translations ?? []
					{
						guard let term = translation["term"] as? String,
						      let context = translation["context"] as? String else
						{
							preconditionFailure()
						}
						
						let translated: TranslatedTerm
						
						if let single = translation["definition"] as? String
						{
							translated = TranslatedTerm.hasDefinition(single)
						}
						else if let plurals = translation["definition"] as? [String: String]
						{
							translated = TranslatedTerm.hasPlurals(plurals)
						}
						else
						{
							preconditionFailure()
						}
						
						let comment = translation["comment"] as? String
						let trans = Translation(comment: comment, term: term, translated: translated)
						
						if var existingTrans = contexts[context]
						{
							existingTrans.append(trans)
							contexts[context] = existingTrans
						}
						else
						{
							contexts[context] = [trans]
						}
					}
					
					print("")
					
					for key in contexts.keys.sorted()
					{
						guard let translations = contexts[key] else { continue }
						
						try writeFile(name: key, translations: translations, to: outputFolderURL)
					}
					
					print("")
				}
				catch let error
				{
					exportError = error
				}
			
			case .failure(let error):
				exportError = error
		}
		
		sema.signal()
	}
	
	sema.wait()
	
	if let error = exportError
	{
		print("Failed")
		print(error)
	}
}

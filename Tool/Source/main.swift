//
//  main.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

let sema = DispatchSemaphore(value: 0)

// load settings from CWD if present
var settings = Settings()

// get token from user if needed
if settings.token == nil
{
	// no api token
	print("Enter POEditor API Token> ", terminator: "")
	settings.token = readLine(strippingNewline: true)
}

// Set up API
let poeditor = POEditor(token: settings.token)

// Show projects to select
if settings.projectID == nil
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
		settings.projectID = Int((project["id"] as! String))
	}
	else
	{
		print("No project selected, aborting.")
		exit(1)
	}
}

// Show languages to select
if settings.languages == nil
{
	var projectLanguages: [JSONDictionary]!
	
	poeditor.listProjectLanguages(projectID: settings.projectID) { result in
		
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
	
	print("\nLanguages Available")
	print("=====================")
	
	for (index, language) in projectLanguages.enumerated()
	{
		guard let code = language["code"] as? String,
			let name = language["name"] as? String,
			let percentComplete = language["percentage"] as? Double else
		{
			continue
		}
		
		let indexStr = String(format: "%3d", index+1)
		
		let codeFormat = code.padding(toLength: 5, withPad: " ", startingAt: 0)
		
		print("\t" + codeFormat + "\t" + name + " (\(percentComplete)%)")
	}
	
	print("\nSelect percent threshold to setup> ", terminator: "")
	
	if let string = readLine(strippingNewline: true),
		let threshold = Double(string)
	{
		let selectedLangs = projectLanguages.filter { (language) -> Bool in
			if let percent = language["percentage"] as? Double, percent >= threshold
			{
				return true
			}
			
			return false
		}
		
		if selectedLangs.count > 0
		{
			settings.languages = selectedLangs.map { (language) -> String in
				return language["code"] as! String
			}
		}
	}
}

if settings.languages == nil || settings.languages?.count == 0
{
	print("No languages selected, aborting.")
	exit(1)
}

// save project settings

if settings.isDirty
{
	do
	{
		try settings.save()
	}
	catch let error
	{
		print(error)
		exit(1)
	}
	
	print("Setup complete. You may edit the config file poet.json to change the imported languages.\n")
}

let workingDirURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let exportFolderURL = workingDirURL.appendingPathComponent("POEditor", isDirectory: true)

let fileManager = FileManager.default

for code in settings.languages.sorted()
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
	
	poeditor.exportProjectTranslation(projectID: settings.projectID, languageCode: code, type: .json) { (result) in
		
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
							translated = TranslatedTerm.hasDefinition(nil)
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

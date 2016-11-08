//
//  main.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

struct Translation
{
	var term: String
	var definition: String?
	var plurals: [String: String]?
	var comment: String?
}

private func writeFile(name: String, translations: [Translation], toPath path: String) throws
{
	let fileManager = FileManager.default
	
	if !fileManager.fileExists(atPath: path)
	{
		try fileManager.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
	}
	
	var fileName = (name as NSString).lastPathComponent
	
	if fileName.isEmpty
	{
		fileName = "Localizable"
	}
	
	guard !(fileName as NSString).pathExtension.isEmpty else
	{
		return
	}
	
	let justName = (fileName as NSString).deletingPathExtension
	
	var tmpStr = ""
	
	for transUnit in translations
	{
		if !tmpStr.isEmpty
		{
			tmpStr += "\n"
		}
		
		if let note = transUnit.comment, !note.isEmpty
		{
			let noteWithLinebreaks = note.replacingOccurrences(of: "\\n", with: "\n", options: [], range: nil)
			tmpStr += "/* \(noteWithLinebreaks) */\n"
		}
		
		// escape double quotes to be safe
		
		var translatedTerm: String!
		
		if let plural = transUnit.plurals?["other"]
		{
			translatedTerm = plural
		}
		else
		{
			translatedTerm = transUnit.definition ?? transUnit.term
		}
		
		let cleanTranslation = translatedTerm.replacingOccurrences(of: "\n", with: "\\n").replacingOccurrences(of: "\"", with: "\\\"")
		
		tmpStr += "\"\(transUnit.term)\" = \"\(cleanTranslation)\";\n"
	}
	
	let outputName = justName + ".strings"
	let outputPath = (path as NSString).appendingPathComponent(outputName)
	
	try (tmpStr as NSString).write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8.rawValue);
	
	print("\t\(outputName) ✓")
	
	let stringsDictItems = translations.filter { (translation) -> Bool in
		return translation.plurals != nil
	}

	if stringsDictItems.count > 0
	{
		var outputDict = [String: Any]()
		
		for translation in stringsDictItems
		{
			var itemDict = [String: Any]()

			itemDict["NSStringLocalizedFormatKey"] = "%#@items@"

			var pluralsDict = [String: Any]()

			pluralsDict["NSStringFormatSpecTypeKey"] = "NSStringPluralRuleType"
			pluralsDict["NSStringFormatValueTypeKey"] = "d"
			
			for key in translation.plurals!.keys.sorted()
			{
				let form = translation.plurals![key]!
				
				pluralsDict[key] = form
			}
			
			itemDict["items"] = pluralsDict
			
			outputDict[translation.term] = itemDict
		}
		
		let outputName = justName + ".stringsdict"
		let outputPath = (path as NSString).appendingPathComponent(outputName)

		(outputDict as NSDictionary).write(toFile: outputPath, atomically: true)
		
		print("\t\(outputName) ✓")
	}
}


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
						
						var trans = Translation(term: term, definition: nil, plurals: nil, comment: nil)
						
						if let single = translation["definition"] as? String
						{
							trans.definition = single
						}
						else if let plurals = translation["definition"] as? [String: String]
						{
							trans.plurals = plurals
						}
						
						trans.comment = translation["comment"] as? String
						
						
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
						
						try writeFile(name: key, translations: translations, toPath: outputFolderURL.path)
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

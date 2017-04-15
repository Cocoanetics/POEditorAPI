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

print("POEditor Tool (POET)")
print("====================")


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
	print("------------------")
	
	for (index, project) in availableProjects.enumerated()
	{
		guard let projectID = project["id"] as? Int,
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
		settings.projectID = project["id"] as? Int
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
	print("-------------------")
	
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

if settings.outputFolder == nil
{
	print("\nSpecify output folder> ", terminator: "")
	
	if let folder = readLine(strippingNewline: true)
	{
		settings.outputFolder = folder
	}
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

var mode = "xcode"

if CommandLine.arguments.count >= 2
{
	mode = CommandLine.arguments[1].lowercased()
}

if mode == "xcode"
{
	export(with: settings, forXcode: true)
}
else if let format = POEditor.ExportFileType(rawValue: mode)
{
	export(with: settings, format: format, forXcode: false)
}
else
{
	print("Unknown mode '\(mode)")
	exit(1)
}

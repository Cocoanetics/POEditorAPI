//
//  Functions.swift
//  POET
//
//  Created by Oliver Drobnik on 08.11.16.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

func xCodeLocaleFromPOEditorCode(code: String) -> String
{
	var tmpCode = code
	
	if tmpCode == "zh-CN"
	{
		tmpCode = "zh-Hans"
	}
	else if tmpCode == "zh-TW"
	{
		tmpCode = "zh-Hant"
	}
	
	let locale = Locale(identifier: tmpCode)
	return locale.identifier
}

func exportFolderURL(settings: Settings) -> URL
{
	// determine output folder: default, relative or absolute
	
	var exportFolderURL: URL
	let outputFolder = settings.outputFolder ?? "POEditor"
	
	if outputFolder.hasPrefix("/")
	{
		exportFolderURL = URL(fileURLWithPath: outputFolder)
	}
	else
	{
		let workingDirURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
		exportFolderURL = workingDirURL.appendingPathComponent(outputFolder, isDirectory: true)
	}
	
	return exportFolderURL
}

func processJSON(data: Data, outputFolderURL: URL) throws
{
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
			translated = TranslatedTerm.notTranslated
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
	
	for key in contexts.keys.sorted()
	{
		guard let translations = contexts[key] else { continue }
		
		try translations.writeFile(name: key, to: outputFolderURL)
	}
}

func export(with settings: Settings, format: ExportType = .json, forXcode: Bool = true)
{
	let exportURL = exportFolderURL(settings: settings)
	
	let langStr = (settings.languages.count == 1) ? "One language" : String(format: "%ld languages", settings.languages.count)
	
	print("\(langStr) will be exported to " + exportURL.path + "\n")
	
	let fileManager = FileManager.default
	
	for code in settings.languages.sorted()
	{
		let xcode = xCodeLocaleFromPOEditorCode(code: code)
		
		print("\nExporting " + Locale(identifier: "en").localizedString(forIdentifier: xcode)! + " [" + xcode + "]...\n")
		
		let outputFolderURL = exportURL.appendingPathComponent(xcode + ".lproj", isDirectory: true)
		
		do
		{
			if !fileManager.fileExists(atPath: exportURL.path)
			{
				try fileManager.createDirectory(at: outputFolderURL, withIntermediateDirectories: true, attributes: nil)
			}
		}
		catch
		{
			print("Unable to create output folder " + outputFolderURL.path)
			exit(1)
		}
		
		var exportError: Error?
		
		poeditor.exportProjectTranslation(projectID: settings.projectID, languageCode: code, type: format) { (result) in
			
			switch result
			{
			case .success(let url):
				
				do
				{
					let data = try Data(contentsOf: url)
					
					if forXcode
					{
						try processJSON(data: data, outputFolderURL: outputFolderURL)
					}
					else
					{
						let outputFileURL = exportURL.appendingPathComponent(xcode).appendingPathExtension(format.rawValue)
						
						let name = outputFileURL.lastPathComponent
						try data.write(to: outputFileURL)
						
						print("\t✓ " + name)
					}
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
			print("\nExport Failed:" + error.localizedDescription)
			exit(1)
		}
	}
	
	print("\nExport complete\n\n")
}


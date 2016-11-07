//
//  main.swift
//  POEditorAPI
//
//  Created by Oliver Drobnik on 05/11/2016.
//  Copyright © 2016 Cocoanetics. All rights reserved.
//

import Foundation

let poeditor = POEditor()

let sema = DispatchSemaphore(value: 0)

poeditor.listProjects { result in
	
	if case .success(let projects) = result
	{
		print(projects)
	}
	sema.signal()
}

sema.wait()

poeditor.exportProjectTranslation(projectID: 41593, languageCode: "de", type: .xliff) { result in
	
	if case .success(let url) = result
	{
		print(url)
	}
	
		sema.signal()
}

//poeditor.createProject(name: "Test4") { result in
//	
//	
//	
//	sema.signal()
//}

sema.wait()



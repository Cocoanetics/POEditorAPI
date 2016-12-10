Please look at the [announcement and video demonstration](https://www.cocoanetics.com/2016/11/introducing-the-poeditor-com-api-and-tool/) at Cocoanetics.com


POEditor.com API
================

An API wrapper written in Swift 3. With it you can add support for POEditor.com to your iOS and macOS apps.

How to Add to your Project
--------------------------

If you use Cocoapods, you can add the following to your Podfile to include the latest version of POEditor API.
  
```
platform :ios, '8.0'

use_frameworks!
project './project.xcodeproj'

target "project" do
	pod 'POEditorAPI'
end
```

If you use git submodules, then clone the GitHub repo into a sub-folder of your project.

`git clone https://github.com/Cocoanetics/POEditorAPI.git Externals/POEditorAPI`

Embed the POEditor framework for your platform into your app, this should cause Xcode to correctly set up the import of the umbrella header.

Smoke Test
----------

At the top you `import POEditorAPI`. Then you can instantiate the API passing your token. You can get a POEditor.com API token from your profile settings page.

```
let poeditor = POEditor(token: "TOKEN")
poeditor.listProjects { (result) in
			
   switch result 
   {
      case .success(let projects):
         print(projects)
				
      case .failure(let error):
         print(error)
   }
}

```

The API makes use of the *Result* paradigm which returns either a .success with the result attached or a .failure with the error attached.


POEditor Tool (POET)
====================

A command line utility that exports specific languages from a POEditor.com project and creates `.strings` and `.stringsdict` files accordingly. Build it and place it in e.g. `/usr/local/bin`. Then run it in the root of a project and follow the prompts. 
Pod::Spec.new do |spec|
  spec.name         = 'POEditorAPI'
  spec.version      = '1.1.0'
  spec.summary      = "A POEditor.com API wrapper, written in Swift 3"
  spec.homepage     = "https://github.com/Cocoanetics/POEditorAPI"
  spec.author       = { "Oliver Drobnik" => "oliver@cocoanetics.com" }
  spec.documentation_url = 'https://github.com/Cocoanetics/POEditorAPI'
  spec.social_media_url = 'https://twitter.com/cocoanetics'
  spec.source       = { :git => "https://github.com/Cocoanetics/POEditorAPI.git", :tag => spec.version.to_s }
  spec.ios.deployment_target = '8.0'
  spec.license      = 'BSD'
  spec.requires_arc = true

  spec.subspec 'Core' do |ss|
    ss.ios.deployment_target = '8.0'
    ss.osx.deployment_target = '10.10'
    ss.source_files = 'Core/Source/*.swift'
  end
end
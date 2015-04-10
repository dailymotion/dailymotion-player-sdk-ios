Pod::Spec.new do |s|

  s.name         = "dailymotion-player-objc"
  s.version      = "2.9.1"
  s.summary      = "Dailymotion Objective-C client API"

  s.description  = <<-DESC
                  The Dailymotion Objective-C player API. This code allows you to
                  easily embed dailymotion.com videos into your app.
                   DESC

  s.homepage     = "https://developer.dailymotion.com/tools/sdks#sdk-objective-c"

  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "Dailymotion iOS Squad" => "squad-everywhere-ios@dailymotion.com" }

  s.platform     = :ios, '7.0'

  s.source       = { :git => "https://github.com/dailymotion/dailymotion-sdk-objc.git", :tag => "2.9.1" }

  s.source_files  = 'dailymotion-player-objc/*.{h,m}'
  
  s.requires_arc = true

end




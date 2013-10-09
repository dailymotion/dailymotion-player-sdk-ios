Pod::Spec.new do |s|

  s.name         = "dailymotion-sdk-objc"
  s.version      = "2.0"
  s.summary      = "Dailymotion Objective-C client API"

  s.description  = <<-DESC
                   The Dailymotion Objective-C client API. This framework allows you to
                   easily add Dailymotion video into your iOS app.
                   DESC

  s.homepage     = "http://www.dailymotion.com/doc/api"

  s.license      = { :type => 'MIT', :file => 'LICENSE' }

  s.author       = { "Oliver Poitrey" => "rs@dailymotion.com" }

  s.platform     = :ios, '5.0'

  s.source       = { :git => "https://github.com/dailymotion/dailymotion-sdk-objc.git", :commit => "879f904e22b67f6b517ad575b2cbf13fab03ea9c" }

  s.source_files  = 'Dailymotion SDK'

  s.frameworks = 'Security', 'SystemConfiguration'

  s.requires_arc = true

  non_arc_files = 'DMAPIArchiverDelegate.m',
                  'DMAPICall.m',
                  'DMAPICallQueue.m',
                  'DMAPIError.m',
                  'DMAPITransfer.m',
                  'DMItem.m',
                  'DMItemCollection.m',
                  'DMItemLocalCollection.m',
                  'DMItemOperation.m',
                  'DMItemRemoteCollection.m',
                  'DMNetRequestOperation.m',
                  'DMNetworking.m',
                  'DMRangeInputStream.m',
                  'DMReachability.m',
                  'DMOAuthRequestOperation.m',
                  'DMOAuthSession.m',
                  'DMItemCollectionViewController.m',
                  'DMItemPickerLabel.m',
                  'DMItemPickerViewDataSource.m',
                  'DMItemTableViewCellDefaultCell.m',
                  'DMItemTableViewController.m',
                  'DMAdditions.m',
                  'DMAlert.m',
                  'DMQueryString.m'

  s.subspec 'no-arc' do |sna|
    sna.requires_arc = false
    sna.source_files = non_arc_files
  end

end




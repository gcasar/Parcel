Pod::Spec.new do |s|
  s.name        = "Parcel"
  s.version     = "1.0.0"
  s.summary     = "Parcel makes it easy to deal with generic key-value data types"
  s.homepage    = "https://github.com/gcasar/Parcel"
  s.license     = { :type => "MIT" }
  s.authors     = { "lingoer" => "lingoerer@gmail.com", "tangplin" => "tangplin@gmail.com", "gcasar" => "gregorcasar@gmail.com" }

  s.requires_arc = true
  s.ios.deployment_target = "8.0"
  s.source   = { :git => "https://github.com/gcasar/Parcel.git", :tag => s.version }
  s.source_files = "Source/*.swift"
  s.pod_target_xcconfig =  {
        'SWIFT_VERSION' => '3.0',
  }
end

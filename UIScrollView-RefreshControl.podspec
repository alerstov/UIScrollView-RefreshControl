Pod::Spec.new do |s|
  s.name             = "UIScrollView-RefreshControl"
  s.version          = "0.1.0"
  s.summary          = "IOS7-like refresh control in any UIScrollView for IOS5+."
  s.homepage         = "https://github.com/alerstov/UIScrollView-RefreshControl"
  s.license          = 'MIT'
  s.author           = { "Alexander Stepanov" => "alerstov@gmail.com" }
  s.source           = { :git => "https://github.com/alerstov/UIScrollView-RefreshControl.git", :tag => s.version.to_s }
  s.platform         = :ios, '5.0'
  s.requires_arc     = true
  s.source_files     = 'UIScrollView-RefreshControl/*.{h,m}'
  s.frameworks       = 'QuartzCore'
end

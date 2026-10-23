Pod::Spec.new do |s|
  s.name             = 'SiroMap'
  s.version          = '1.0.0'
  s.summary          = 'Commercial Maps SDK for iOS (Swift) by Siro Platform.'
  s.description      = <<-DESC
    High-performance commercial map SDK for iOS offering high-resolution 2D vector maps,
    3D terrain elevation mesh, 3D architectural extrusions, routing, forward/reverse geocoding
    in Arabic and English.
                       DESC

  s.homepage         = 'https://map-saas.intaleqapp.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Hamza Ayed' => 'hamzaayedflutter@gmail.com' }
  s.source           = { :git => 'https://github.com/Hamza-Ayed/siro_map_ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '14.0'
  s.swift_version    = '5.9'

  s.source_files = 'Sources/SiroMap/**/*'
  s.frameworks   = 'WebKit', 'CoreLocation', 'SwiftUI'
end

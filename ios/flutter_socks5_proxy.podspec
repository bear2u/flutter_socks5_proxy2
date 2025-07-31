#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_socks5_proxy.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_socks5_proxy'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter package for easy SOCKS5 proxy configuration.'
  s.description      = <<-DESC
A Flutter package for easy SOCKS5 proxy configuration with simple connect/disconnect API.
                       DESC
  s.homepage         = 'https://github.com/yourusername/flutter_socks5_proxy'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Name' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
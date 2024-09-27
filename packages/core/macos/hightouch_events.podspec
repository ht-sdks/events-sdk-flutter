#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint hightouch_events.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'hightouch_events'
  s.version          = '0.0.1'
  s.summary          = 'Hightouch Events Flutter MacOS plugin'
  s.description      = <<-DESC
Hightouch Events Flutter MacOS plugin
                       DESC
  s.homepage         = 'https://hightouch.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hightouch' => 'support@hightouch.io' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end

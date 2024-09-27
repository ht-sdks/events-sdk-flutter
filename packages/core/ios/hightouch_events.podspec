#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint hightouch_events.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'hightouch_events'
  s.version          = '0.0.1'
  s.summary          = 'The hassle-free way to add Hightouch Events to your Flutter app.'
  s.description      = <<-DESC
The hassle-free way to add Hightouch Events to your Flutter app.
                       DESC
  s.homepage         = 'https://hightouch.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hightouch' => 'support@hightouch.io' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

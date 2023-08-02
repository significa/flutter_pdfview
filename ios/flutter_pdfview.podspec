#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#
Pod::Spec.new do |s|
  s.name             = 'flutter_pdfview'
  s.version          = '1.0.2'
  s.summary          = 'Flutter plugin that display a pdf using PDFkit.'
  s.description      = <<-DESC
  A Flutter plugin for display pdf from the library as well as from url
  Downloaded by pub (not CocoaPods).
                       DESC
  s.homepage         = 'https://github.com/endigo/flutter_pdfview'
  s.license          = { :type => 'BSD', :file => '../LICENSE' }
  s.author           = { 'endigo' => 'endigo.18@gmail.com' }
  s.source           = { :http => 'https://github.com/endigo/flutter_pdfview' }
  s.documentation_url = 'https://pub.dev/packages/flutter_pdfview'
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end


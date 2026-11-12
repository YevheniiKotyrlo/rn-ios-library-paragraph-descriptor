Pod::Spec.new do |s|
  s.name = 'library-descriptors'
  s.version = '0.0.0'
  s.summary = 'A library that registers its own View and Paragraph component descriptors'
  s.homepage = 'https://github.com/YevheniiKotyrlo/rn-ios-library-paragraph-descriptor'
  s.license = 'MIT'
  s.authors = 'rn-ios-library-paragraph-descriptor'
  s.platforms = { :ios => min_ios_version_supported }
  s.source = { :git => 'https://github.com/YevheniiKotyrlo/rn-ios-library-paragraph-descriptor.git' }
  s.source_files = 'ios/**/*.{h,mm}'

  install_modules_dependencies(s)
end

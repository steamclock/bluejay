Pod::Spec.new do |spec|
  spec.name = 'Bluejay'
  spec.version = '0.8.4'
  spec.license = { type: 'MIT', file: 'LICENSE' }
  spec.homepage = 'https://github.com/steamclock/bluejay'
  spec.authors = { 'Jeremy Chiang' => 'jeremy@steamclock.com' }
  spec.summary = 'Bluejay is a simple Swift framework for building reliable Bluetooth apps.'
  spec.homepage = 'https://github.com/steamclock/bluejay'
  spec.source = { git: 'https://github.com/steamclock/bluejay.git', tag: 'v0.8.4' }
  spec.source_files = 'Bluejay/Bluejay/*.{h,swift}'
  spec.framework = 'SystemConfiguration'
  spec.platform = :ios, '10.0'
  spec.requires_arc = true
  spec.dependency 'XCGLogger', '~> 6.1.0'
  spec.swift_version = '4.2'
end

Pod::Spec.new do |spec|
  spec.name = 'Bluejay'
  spec.version = '0.5.1'
  spec.license = { type: 'MIT', file: 'LICENSE' }
  spec.homepage = 'https://github.com/steamclock/bluejay'
  spec.authors = { 'Jeremy Chiang' => 'jeremy@steamclock.com' }
  spec.summary = 'Bluejay is a simple Swift framework for building reliable Bluetooth apps.'
  spec.homepage = 'https://github.com/steamclock/bluejay'
  spec.source = { git: 'https://github.com/steamclock/bluejay.git', tag: 'v0.5.1' }
  spec.source_files = 'Bluejay/Bluejay/*.{h,swift}'
  spec.framework = 'SystemConfiguration'
  spec.platform = :ios, '9.3'
  spec.requires_arc = true
end

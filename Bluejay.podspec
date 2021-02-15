Pod::Spec.new do |spec|
  spec.name = 'Bluejay'
  spec.version = '0.8.8'
  spec.license = { type: 'MIT', file: 'LICENSE' }
  spec.homepage = 'https://github.com/neurovalens/bluejay'
  spec.authors = { 'Jeremy Chiang' => 'jeremy@steamclock.com', 'Chris McCabe' => 'chris.mccabe@neurovalens.com' }
  spec.summary = 'Bluejay is a simple Swift framework for building reliable Bluetooth apps.'
  spec.homepage = 'https://github.com/steamclock/bluejay'
  spec.source = { git: 'https://github.com/neurovalens/bluejay.git', tag: 'v0.8.6' }
  spec.source_files = 'Bluejay/Bluejay/*.{h,swift}'
  spec.framework = 'SystemConfiguration'
  spec.platform = :ios, '10.0'
  spec.requires_arc = true
  spec.swift_version = '5.0'
end

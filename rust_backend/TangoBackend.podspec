Pod::Spec.new do |spec|
  spec.name = 'TangoBackend'
  spec.version = '0.1.0'
  spec.summary = 'Rust backend bindings for Tango'
  spec.homepage = 'https://tango.com'
  spec.license = { :type => 'MIT', :file => 'LICENSE' }
  spec.author = { 'Tango' => 'noreply@tango.local' }
  spec.source = { :path => '.' }
  spec.ios.deployment_target = '16.0'
  spec.swift_version = '5.0'
  spec.static_framework = true
  # build_rust_backend.sh stages this spec beside the generated iOS artifacts.
  spec.source_files = 'TangoBackend.swift'
  spec.vendored_frameworks = 'TangoBackendFFI.xcframework'
  spec.frameworks = 'Security', 'CoreFoundation'
end

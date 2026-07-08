library_path = File.join(__dir__, 'Libs', 'libaudiotags.a')
unless File.exist?(library_path)
  raise "Missing vendored audiotags macOS library at #{library_path}. Commit the prebuilt libaudiotags.a before building."
end

Pod::Spec.new do |s|
  s.name             = 'audiotags'
  s.version          = '1.4.5'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.vendored_libraries = 'Libs/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'OTHER_LDFLAGS' => '-force_load ${PODS_TARGET_SRCROOT}/Libs/libaudiotags.a',
  }
  s.swift_version = '5.0'
end

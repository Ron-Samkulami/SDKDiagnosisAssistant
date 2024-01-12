
Pod::Spec.new do |s|
    s.name             = 'SDKDiagnosisAssistant'
    s.version          = '0.1.0'
    s.summary          = 'SDK诊断助手'
    
    s.description      = <<-DESC
    SDK诊断助手.
    DESC
    
    s.homepage         = 'https://github.com/Ron-Samkulami/SDKDiagnosisAssistant'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'Ron-Samkulami' => '1402434985@qq.com' }
    s.source           = { :git => 'https://github.com/Ron-Samkulami/SDKDiagnosisAssistant.git', :tag => s.version.to_s }
    
    s.ios.deployment_target = '12.0'
    
    s.static_framework = true
    
    # build setting
    s.pod_target_xcconfig = {
        'DEFINES_MODULE' => 'NO',
        'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
    }
    
    s.user_target_xcconfig = {
        'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64',
        'OTHER_LDFLAGS' => '-lc++',
    }
    
    s.source_files = 'SDKDiagnosisAssistant/Classes/**/*'
    s.public_header_files = 'SDKDiagnosisAssistant/Classes/**/*.{h}'
    
end

Pod::Spec.new do |s|
  s.name = 'ProbePod'
  s.version = '0.2.0'
  s.summary = 'Synthetic binary consumption probe'
  s.homepage = 'https://github.com/comsy-devex-lab/spm-probe-public'
  s.license = { :type => 'MIT', :file => 'LICENSE' }
  s.author = { 'Probe' => 'probe@example.invalid' }
  s.source = { :git => 'https://github.com/comsy-devex-lab/spm-probe-public.git', :tag => 'v0.2.0' }
  s.ios.deployment_target = '15.0'
  s.module_name = 'ProbeBinary'
  s.vendored_frameworks = 'ProbeBinary.xcframework'
end

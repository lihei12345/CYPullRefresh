Pod::Spec.new do |spec|
  spec.name         = 'CYPullRefresh'
  spec.version      = '0.2'
  spec.authors      = 'Jason li'
  spec.homepage     = 'http://blog.csdn.net/lihei12345'
  spec.source       = { :git => 'https://github.com/lihei12345/CYPullRefresh.git', :tag => "#{spec.version}"}
  spec.license      = {
      :type => 'Copyright',
      :text => <<-LICENSE
      Copyright 2015 Jason. All rights reserved.
      LICENSE
  }
  spec.summary      = 'use pull-refresh and load-more easily'
  spec.source_files = 'CYPullRefresh/CYPullRefresh/*.{h,m}'
  spec.platform     = :ios
  spec.requires_arc = true
  spec.ios.deployment_target = '6.0'
end
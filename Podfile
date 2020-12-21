target 'axewallet' do
  platform :ios, '12.0'
  
  pod 'AxeSync', :path => '../AxeSync/'
  pod 'DAPI-GRPC', :path => '../AxeSync/'

  pod 'CloudInAppMessaging', '0.1.0'
  
  pod 'KVO-MVVM', '0.5.6'
  pod 'UIViewController-KeyboardAdditions', '1.2.1'
  pod 'MBProgressHUD', '1.1.0'
  pod 'MMSegmentSlider', :git => 'https://github.com/podkovyrin/MMSegmentSlider', :commit => '2d91366'

  # Debugging purposes
#  pod 'Reveal-SDK', :configurations => ['Debug']
  
  target 'AxeWalletTests' do
    inherit! :search_paths
  end

  target 'AxeWalletScreenshotsUITests' do
    inherit! :search_paths
  end

end

target 'TodayExtension' do
  platform :ios, '12.0'
  
  pod 'DSDynamicOptions', '0.1.1'

end

target 'WatchApp' do
  platform :watchos, '2.0'

end

target 'WatchApp Extension' do
  platform :watchos, '2.0'

end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        # fixes warnings about unsupported Deployment Target in Xcode 10
        if ["BoringSSL-GRPC", "abseil", "gRPC", "gRPC-Core", "gRPC-RxLibrary", "gRPC-ProtoRPC", "Protobuf", "DSJSONSchemaValidation", "!ProtoCompiler", "!ProtoCompiler-gRPCPlugin", "gRPC-gRPCCertificates", "UIViewController-KeyboardAdditions", "MMSegmentSlider", "MBProgressHUD", "KVO-MVVM", "CocoaLumberjack"].include? target.name
            target.build_configurations.each do |config|
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
            end
        end
        
        # Hide warnings for specific pods
        if ["gRPC"].include? target.name
            target.build_configurations.each do |config|
                config.build_settings['GCC_WARN_INHIBIT_ALL_WARNINGS'] = 'YES'
            end
        end
        
        # temporary solution to work with gRPC-Core
        # see https://github.com/CocoaPods/CocoaPods/issues/8474
        if target.name == 'secp256k1_axe'
          target.build_configurations.each do |config|
              config.build_settings['HEADER_SEARCH_PATHS'] = '"${PODS_ROOT}/Headers/Private" "${PODS_ROOT}/Headers/Private/secp256k1_axe" "${PODS_ROOT}/Headers/Public" "${PODS_ROOT}/Headers/Public/secp256k1_axe"'
          end
        end
    end
    
    # update info about current AxeSync version
    # the command runs in the background after 1 sec, when `pod install` updates Podfile.lock
    system("(sleep 1; sh ./scripts/axesync_version.sh) &")
end

target 'axewallet' do
  platform :ios, '10.0'
  
  pod 'AxeSync', :path => '../AxeSync/'
  
  pod 'KVO-MVVM', '0.5.1'

  # Pods for axewallet
  
  target 'AxeWalletTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'AxeWalletUITests' do
    inherit! :search_paths
    # Pods for testing
  end

end

target 'TodayExtension' do

end

target 'WatchApp' do
  platform :watchos, '2.0'

end

target 'WatchApp Extension' do
  platform :watchos, '2.0'

end

# fixes warnings about unsupported Deployment Target in Xcode 10
post_install do |installer|
    installer.pods_project.targets.each do |target|
        if target.name == 'AFNetworking'
            target.build_configurations.each do |config|
                config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '8.0'
            end
        end
    end
    
    # update info about current AxeSync version
    system("bash scripts/axesync_version.sh")
end

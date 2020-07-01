target 'axewallet' do
  platform :ios, '11.0'
  
  pod 'AxeSync', :git => 'https://github.com/axerunners/axesync/', :commit => '70f06b7a43a6ef30c9ab25425ba974f52b680e3f'
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
  platform :ios, '11.0'
  
  pod 'DSDynamicOptions', '0.1.0'

end

target 'WatchApp' do
  platform :watchos, '2.0'

end

target 'WatchApp Extension' do
  platform :watchos, '2.0'

end

post_install do |installer|
    # update info about current AxeSync version
    # the command runs in the background after 1 sec, when `pod install` updates Podfile.lock
    system("(sleep 1; sh ./scripts/axesync_version.sh) &")
end

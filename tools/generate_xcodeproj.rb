#!/usr/bin/env ruby

require 'fileutils'
require 'xcodeproj'

PROJECT_NAME = 'CalendarPro'
PROJECT_PATH = "#{PROJECT_NAME}.xcodeproj"
DEPLOYMENT_TARGET = '14.0'
TESTING_INTEROP_DYLIB_PATH = '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/lib_TestingInterop.dylib'
TESTING_FRAMEWORKS_DIR = '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/Library/Frameworks'

FileUtils.rm_rf(PROJECT_PATH)
project = Xcodeproj::Project.new(PROJECT_PATH)

app_target = project.new_target(:application, PROJECT_NAME, :osx, DEPLOYMENT_TARGET)
test_target = project.new_target(:unit_test_bundle, "#{PROJECT_NAME}Tests", :osx, DEPLOYMENT_TARGET)
ui_test_target = project.new_target(:ui_test_bundle, "#{PROJECT_NAME}UITests", :osx, DEPLOYMENT_TARGET)
test_target.add_dependency(app_target)
ui_test_target.add_dependency(app_target)

[app_target, test_target, ui_test_target].each do |target|
  target.build_configurations.each do |config|
    config.build_settings['SWIFT_VERSION'] = '6.0'
    config.build_settings['MACOSX_DEPLOYMENT_TARGET'] = DEPLOYMENT_TARGET
    config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
    config.build_settings['CLANG_ENABLE_MODULES'] = 'YES'
    config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    config.build_settings['CODE_SIGN_STYLE'] = 'Automatic'
    config.build_settings['PRODUCT_NAME'] = '$(TARGET_NAME)'
  end
end

app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.yelog.CalendarPro'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'CalendarPro/CalendarPro.entitlements'
  config.build_settings['INFOPLIST_KEY_LSUIElement'] = config.name == 'Release' ? 'YES' : 'NO'
  config.build_settings['INFOPLIST_KEY_NSCalendarsUsageDescription'] = '用于显示您的日历日程'
  config.build_settings['INFOPLIST_KEY_NSRemindersUsageDescription'] = '用于显示您的提醒事项'
  config.build_settings['DEFINES_MODULE'] = 'YES'
  config.build_settings['SWIFT_EMIT_LOC_STRINGS'] = 'YES'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @executable_path/../Frameworks'
  config.build_settings['MARKETING_VERSION'] = '1.0.0'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
end

project.root_object.attributes['TargetAttributes'] ||= {}
project.root_object.attributes['TargetAttributes'][app_target.uuid] = {
  'ProvisioningStyle' => 'Automatic'
}

# ─── SwiftPM dependencies ───
sparkle_pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
sparkle_pkg.repositoryURL = 'https://github.com/sparkle-project/Sparkle'
sparkle_pkg.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => '2.6.4' }
project.root_object.package_references << sparkle_pkg

sparkle_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
sparkle_dep.product_name = 'Sparkle'
sparkle_dep.package = sparkle_pkg
app_target.package_product_dependencies << sparkle_dep

tyme_pkg = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
tyme_pkg.repositoryURL = 'https://github.com/xuanyunhui/tyme4swift'
tyme_pkg.requirement = { 'kind' => 'upToNextMajorVersion', 'minimumVersion' => '1.4.3' }
project.root_object.package_references << tyme_pkg

tyme_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
tyme_dep.product_name = 'tyme'
tyme_dep.package = tyme_pkg
app_target.package_product_dependencies << tyme_dep

test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.yelog.CalendarProTests'
  config.build_settings['TEST_HOST'] = '$(BUILT_PRODUCTS_DIR)/CalendarPro.app/Contents/MacOS/CalendarPro'
  config.build_settings['BUNDLE_LOADER'] = '$(TEST_HOST)'
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @loader_path/../Frameworks @loader_path/../../Frameworks'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end

ui_test_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.yelog.CalendarProUITests'
  config.build_settings['TEST_TARGET_NAME'] = PROJECT_NAME
  config.build_settings['LD_RUNPATH_SEARCH_PATHS'] = '$(inherited) @loader_path/../Frameworks @loader_path/../../Frameworks'
  config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
end

ui_test_embed_phase = ui_test_target.new_shell_script_build_phase('Embed Testing Interop')
ui_test_embed_phase.shell_script = <<~SCRIPT
  TESTING_INTEROP_DYLIB_PATH="#{TESTING_INTEROP_DYLIB_PATH}"
  TESTING_FRAMEWORKS_DIR="#{TESTING_FRAMEWORKS_DIR}"
  RUNNER_FRAMEWORKS_DIR="$TARGET_BUILD_DIR/../Frameworks"

  if [ ! -f "$TESTING_INTEROP_DYLIB_PATH" ]; then
    echo "warning: Missing lib_TestingInterop.dylib at $TESTING_INTEROP_DYLIB_PATH"
    exit 0
  fi

  mkdir -p "$RUNNER_FRAMEWORKS_DIR"
  cp "$TESTING_INTEROP_DYLIB_PATH" "$RUNNER_FRAMEWORKS_DIR/lib_TestingInterop.dylib"

  for framework in "$TESTING_FRAMEWORKS_DIR"/_Testing*.framework; do
    if [ ! -e "$framework" ]; then
      continue
    fi

    framework_name="$(basename "$framework")"
    rm -rf "$RUNNER_FRAMEWORKS_DIR/$framework_name"
    ditto "$framework" "$RUNNER_FRAMEWORKS_DIR/$framework_name"
  done
SCRIPT

def add_project_files(group, app_target, test_target, ui_test_target, path, role)
  Dir.children(path).sort.each do |entry|
    next if entry.start_with?('.')

    full_path = File.join(path, entry)
    if File.directory?(full_path)
      # Treat .xcassets as opaque resource bundles, not as directories to recurse into
      if File.extname(entry) == '.xcassets'
        file_ref = group.new_file(entry)
        app_target.resources_build_phase.add_file_reference(file_ref) if role == :app
      else
        subgroup = group.new_group(entry, entry)
        add_project_files(subgroup, app_target, test_target, ui_test_target, full_path, role)
      end
    elsif File.extname(entry) == '.swift'
      file_ref = group.new_file(entry)
      target = case role
               when :app
                 app_target
               when :test
                 test_target
               else
                 ui_test_target
               end
      target.source_build_phase.add_file_reference(file_ref)
    elsif role == :app && File.extname(entry) == '.entitlements'
      group.new_file(entry)
    elsif role == :app && ['.json', '.xcstrings'].include?(File.extname(entry))
      file_ref = group.new_file(entry)
      app_target.resources_build_phase.add_file_reference(file_ref)
    end
  end
end

app_group = project.main_group.new_group(PROJECT_NAME, PROJECT_NAME)
tests_group = project.main_group.new_group("#{PROJECT_NAME}Tests", "#{PROJECT_NAME}Tests")
ui_tests_group = project.main_group.new_group("#{PROJECT_NAME}UITests", "#{PROJECT_NAME}UITests")

add_project_files(app_group, app_target, test_target, ui_test_target, PROJECT_NAME, :app)
add_project_files(tests_group, app_target, test_target, ui_test_target, "#{PROJECT_NAME}Tests", :test)
if Dir.exist?("#{PROJECT_NAME}UITests")
  add_project_files(ui_tests_group, app_target, test_target, ui_test_target, "#{PROJECT_NAME}UITests", :ui_test)
end

scheme = Xcodeproj::XCScheme.new
scheme.configure_with_targets(app_target, test_target, launch_target: app_target)
scheme.add_build_target(ui_test_target, false)
scheme.add_test_target(ui_test_target)
scheme.save_as(PROJECT_PATH, PROJECT_NAME, true)

project.save

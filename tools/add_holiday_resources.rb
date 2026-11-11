#!/usr/bin/env ruby

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../CalendarPro.xcodeproj', __dir__)
RESOURCE_DIR = File.expand_path(
  '../CalendarPro/Resources/Holidays/mainland-cn',
  __dir__
)

project = Xcodeproj::Project.open(PROJECT_PATH)
target = project.targets.find { |candidate| candidate.name == 'CalendarPro' }
abort 'CalendarPro target not found' unless target

group = project.main_group['CalendarPro']&.[]('Resources')&.[]('Holidays')&.[]('mainland-cn')
abort 'mainland-cn holiday group not found' unless group

existing_references = group.children.each_with_object({}) do |child, references|
  next unless child.isa == 'PBXFileReference'
  next unless child.path&.end_with?('.json')

  references[child.path] = child
end

resources_phase = target.resources_build_phase
registered_paths = resources_phase.files_references.compact.map(&:path).compact
changed = false

Dir.glob(File.join(RESOURCE_DIR, '*.json')).sort.each do |path|
  filename = File.basename(path)
  reference = existing_references[filename]

  unless reference
    reference = group.new_file(filename)
    existing_references[filename] = reference
    changed = true
  end

  next if registered_paths.include?(filename)

  resources_phase.add_file_reference(reference)
  changed = true
end

if changed
  project.save
  puts 'Registered holiday resources in CalendarPro.xcodeproj'
else
  puts 'Holiday resources are already registered'
end

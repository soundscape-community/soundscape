#!/usr/bin/env ruby
# Copyright (c) Soundscape Community Contributors.

require 'base64'
require 'pilot'

def input(name)
  value = ENV.fetch(name, '').strip
  value.empty? ? nil : value
end

begin
  %w[APP_STORE_P8_BASE64 APP_STORE_KEY_ID APP_STORE_ISSUER_ID].each do |name|
    abort "Missing #{name}. Check the Production environment secrets." unless input(name)
  end
  groups = input('TESTFLIGHT_GROUPS').to_s.split(',').map(&:strip).reject(&:empty?).uniq
  abort 'Specify at least one external TestFlight group name or ID.' if groups.empty?

  # Keep the decoded key in memory; never write it to a file or print it.
  api_key = {
    key_id: input('APP_STORE_KEY_ID'),
    issuer_id: input('APP_STORE_ISSUER_ID'),
    key: Base64.strict_decode64(input('APP_STORE_P8_BASE64').gsub(/\s+/, '')),
    in_house: false
  }
  Spaceship::ConnectAPI.token = Spaceship::ConnectAPI::Token.create(**api_key)
  app = Spaceship::ConnectAPI::App.find('services.soundscape')
  abort 'The API key cannot access the services.soundscape app.' unless app

  external_groups = app.get_beta_groups.reject(&:is_internal_group)
  selected_groups = groups.map do |identifier|
    matches = external_groups.select { |group| group.id == identifier || group.name == identifier }
    abort "External group #{identifier.inspect} was not found uniquely. Available groups: #{external_groups.map(&:name).join(', ')}" unless matches.length == 1
    matches.first
  end

  # Freeze the selection before making changes. Never silently fall back to an
  # older build when the latest upload is processing, expired, or invalid.
  build = Spaceship::ConnectAPI::Build.all(
    app_id: app.id,
    version: input('TESTFLIGHT_APP_VERSION'),
    build_number: input('TESTFLIGHT_BUILD_NUMBER'),
    platform: 'IOS',
    sort: '-uploadedDate'
  ).first
  abort 'No uploaded iOS build matches the requested version/build.' unless build
  abort "Build #{build.version} is expired." if build.expired
  abort "Build #{build.version} is #{build.processing_state}. Wait for processing or fix the upload, then rerun." unless build.processing_state == 'VALID'
  audience = Spaceship::ConnectAPI.get_build(build_id: build.id).body.dig('data', 'attributes', 'buildAudienceType')
  if audience == 'INTERNAL_ONLY'
    abort 'This build was uploaded as TestFlight Internal Only. Upload a new build using App Store Connect distribution in Xcode.'
  end
  if build.uses_non_exempt_encryption.nil? || build.missing_export_compliance?
    abort 'Complete export compliance for this build in App Store Connect, then rerun.'
  end
  allowed_states = %w[READY_FOR_BETA_SUBMISSION WAITING_FOR_BETA_REVIEW IN_BETA_REVIEW BETA_APPROVED READY_FOR_BETA_TESTING IN_BETA_TESTING]
  state = build.build_beta_detail&.external_build_state
  abort "Build cannot be distributed externally in state #{state.inspect}. Check TestFlight in App Store Connect." unless allowed_states.include?(state)

  puts "Selected #{build.app_version} (#{build.version}), uploaded #{build.uploaded_date}."
  puts "External groups: #{selected_groups.map(&:name).join(', ')}"
  options = {
    api_key: api_key,
    app_identifier: 'services.soundscape',
    app_platform: 'ios',
    distribute_only: true,
    distribute_external: true,
    submit_beta_review: true,
    notify_external_testers: true,
    groups: selected_groups.map(&:id),
    app_version: build.app_version,
    build_number: build.version
  }
  options[:changelog] = input('TESTFLIGHT_CHANGELOG') if input('TESTFLIGHT_CHANGELOG')
  config = FastlaneCore::Configuration.create(Pilot::Options.available_options, options)
  Pilot::BuildManager.new.distribute(config, build: build)

  state = Spaceship::ConnectAPI::Build.get(build_id: build.id).build_beta_detail.external_build_state
  message = "#{build.app_version} (#{build.version}) assigned to #{selected_groups.map(&:name).join(', ')}. External state: #{state}. Apple beta review may be required before testers can install it."
  puts message
  File.open(ENV['GITHUB_STEP_SUMMARY'], 'a') { |file| file.puts(message) } if ENV['GITHUB_STEP_SUMMARY']
rescue StandardError => error
  warn "TestFlight release failed: #{error.message}"
  exit 1
end

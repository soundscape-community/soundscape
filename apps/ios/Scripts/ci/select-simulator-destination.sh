#!/bin/zsh

set -euo pipefail

ruby -rjson -e '
preferred = ["iPhone 17 Pro", "iPhone 16", "iPhone 16 Pro", "iPhone 17"]
devices = JSON.parse(`xcrun simctl list devices available -j`)["devices"]
candidates = []

devices.each do |runtime, runtime_devices|
  match = /iOS-(\d+)-(\d+)$/.match(runtime)
  next unless match

  runtime_devices.each do |device|
    next unless device["isAvailable"]
    next unless device["name"].start_with?("iPhone")

    normalized_name = device["name"].sub(/ \(iOS \d+\.\d+\)\z/, "")
    preference = preferred.index(normalized_name) || preferred.length
    candidates << [-match[1].to_i, -match[2].to_i, preference, normalized_name, device["udid"]]
  end
end

abort("No available iPhone simulator destination is installed on this runner") if candidates.empty?

major, minor, _, name, udid = candidates.min
warn("Using simulator device #{name} on iOS #{-major}.#{-minor} (#{udid})")
puts("platform=iOS Simulator,id=#{udid}")
'

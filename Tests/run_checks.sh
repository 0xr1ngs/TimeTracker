#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/checks build/previews
swiftc Sources/Models/RestReminderSchedule.swift Tests/RestReminderScheduleTests.swift -o build/checks/ReminderChecks
build/checks/ReminderChecks
awk '/^@main/ {exit} {print}' Sources/App/TimeTrackerApp.swift > build/checks/WindowManager.swift
sources=()
while IFS= read -r source; do
    sources+=("$source")
done < <(find Sources -name '*.swift' ! -path 'Sources/App/TimeTrackerApp.swift')
swiftc -parse-as-library "${sources[@]}" build/checks/WindowManager.swift Tests/AppChecks.swift -o build/checks/AppChecks
build/checks/AppChecks "$(pwd)/build/previews"

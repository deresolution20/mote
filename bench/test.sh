#!/bin/zsh
# Run the bench unit tests on a CommandLineTools-only machine.
# CLT ships Testing.framework outside SwiftPM's default search paths, so the
# framework and its interop dylib have to be wired in by hand (XCTest isn't
# present in CLT at all — tests use Swift Testing).
set -e
cd "$(dirname "$0")"
FWK=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
LIB=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
exec swift test --disable-xctest \
  -Xswiftc -F -Xswiftc "$FWK" \
  -Xlinker -F -Xlinker "$FWK" \
  -Xlinker -rpath -Xlinker "$FWK" \
  -Xlinker -rpath -Xlinker "$LIB" "$@"

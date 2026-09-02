#!/bin/zsh

package_app_archive() {
  local app_path="$1"
  local archive_path="$2"

  if [[ -e "$archive_path" ]]; then
    rm -f "$archive_path"
  fi
  mkdir -p "$(dirname "$archive_path")"
  ditto -c -k --keepParent "$app_path" "$archive_path"
}

notarize_app_archive() {
  local app_path="$1"
  local archive_path="$2"
  local keychain_profile="$3"

  xcrun notarytool submit "$archive_path" --keychain-profile "$keychain_profile" --wait
  xcrun stapler staple "$app_path"
  xcrun stapler validate "$app_path"
  spctl --assess --type execute --verbose=4 "$app_path"
  package_app_archive "$app_path" "$archive_path"
}

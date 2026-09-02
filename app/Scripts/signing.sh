#!/bin/zsh

# Resolve and apply the signing policy used by the bundle and release scripts.
# CODESIGN_IDENTITY_LIST is injectable for tests; normal builds query Keychain.

resolve_signing_identity() {
  local mode="${1:-development}"
  local requested="${SIGNING_IDENTITY:-}"
  local identity_list="${CODESIGN_IDENTITY_LIST:-}"
  local identity

  if [[ -n "$requested" ]]; then
    if [[ "$mode" == "release" && "$requested" != "Developer ID Application: "* ]]; then
      print -u2 -- "error: release mode requires a Developer ID Application identity; got '$requested'"
      return 1
    fi
    print -r -- "$requested"
    return 0
  fi

  if [[ -z "$identity_list" ]]; then
    identity_list="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  fi

  for identity in "${(@f)$(print -r -- "$identity_list" | sed -nE 's/.*"([^"]+)".*/\1/p')}"; do
    if [[ "$mode" == "release" && "$identity" == "Developer ID Application: "* ]]; then
      print -r -- "$identity"
      return 0
    fi
    if [[ "$mode" != "release" && "$identity" == "LocalFlow Dev" ]]; then
      print -r -- "$identity"
      return 0
    fi
  done

  if [[ "$mode" == "release" ]]; then
    print -u2 -- "error: no Developer ID Application identity found in the login Keychain"
    print -u2 -- "       Set SIGNING_IDENTITY to the exact certificate name, or install the certificate in Keychain Access."
    return 1
  fi

  # Ad-hoc signing remains available for local development only.
  print -r -- "-"
}

sign_app_bundle() {
  local app_path="$1"
  local mode="${2:-development}"
  local bundle_identifier="${BUNDLE_IDENTIFIER:-dev.brice.mote}"
  local identity
  local -a sign_args

  identity="$(resolve_signing_identity "$mode")" || return 1
  sign_args=(--force --sign "$identity" --identifier "$bundle_identifier")

  if [[ "$mode" == "release" ]]; then
    sign_args+=(--options runtime --timestamp)
  fi

  codesign "${sign_args[@]}" "$app_path"
  codesign --verify --deep --strict --verbose=2 "$app_path"
}

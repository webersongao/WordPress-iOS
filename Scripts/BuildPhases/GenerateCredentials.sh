#!/bin/bash -euo pipefail

# The Secrets File Sources
SECRETS_ROOT="${HOME}/.configure/wordpress-ios/secrets"

# To help the Xcode build system optimize the build, we want to ensure each of
# the secrets we want to copy is defined as an input file for the run script
# build phase.
#
# > The Xcode Build System will use [these files] to determine if your run
# > scripts should actually run or not. So this should include any file that
# > your run script phase, the script content, is actually going to read or
# > look at during its process.
#
# > If you have no input files declared, the Xcode build system will need to
# > run your run script phase on every single build.
#
# https://developer.apple.com/videos/play/wwdc2018/408/
function ensure_is_in_input_files_list() {
  # Loop through the file input lists looking for $1. If not found, fail the
  # build.
  if [ -z "$1" ]; then
    echo "error: Input file list verification needs a path to verify!"
    exit 1
  fi
  file_to_find=$1

  i=0
  found=false
  while [[ $i -lt $SCRIPT_INPUT_FILE_LIST_COUNT && "$found" = false ]]
  do
    # Need this two step process to access the input at index
    file_list_resolved_var_name=SCRIPT_INPUT_FILE_LIST_${i}
    # The following reads the processed xcfilelist line by line looking for
    # the given file
    while read input_file; do
      if [ "$file_to_find" == "$input_file" ]; then
        found=true
        break
      fi
    done <"${!file_list_resolved_var_name}"
    let i=i+1
  done
  if [ "$found" = false ]; then
    echo "error: Could not find $file_to_find as an input to the build phase. Add $file_to_find to the input files list using the .xcfilelist."
    exit 1
  fi
}

WORDPRESS_SECRETS_FILE="${SECRETS_ROOT}/WordPress-Secrets.swift"
ensure_is_in_input_files_list $WORDPRESS_SECRETS_FILE
JETPACK_SECRETS_FILE="${SECRETS_ROOT}/Jetpack-Secrets.swift"
ensure_is_in_input_files_list $JETPACK_SECRETS_FILE

LOCAL_SECRETS_FILE="${SRCROOT}/Credentials/Secrets.swift"
EXAMPLE_SECRETS_FILE="${SRCROOT}/Credentials/Secrets-example.swift"
ensure_is_in_input_files_list $EXAMPLE_SECRETS_FILE

# The Secrets file destination
SECRETS_DESTINATION_FILE="${BUILD_DIR}/Secrets/Secrets.swift"
mkdir -p $(dirname "$SECRETS_DESTINATION_FILE")

# If the WordPress Production Secrets are available for WordPress, use them
if [ -f "$WORDPRESS_SECRETS_FILE" ] && [ "${TARGET_NAME}" == "WordPress" ]; then
    echo "Applying Production Secrets"
    cp -v "$WORDPRESS_SECRETS_FILE" "${SECRETS_DESTINATION_FILE}"
    exit 0
fi

# If the Jetpack Secrets are available (and if we're building Jetpack) use them
if [ -f "$JETPACK_SECRETS_FILE" ] && [ "${TARGET_NAME}" == "Jetpack" ]; then
    echo "Applying Jetpack Secrets"
    cp -v "$JETPACK_SECRETS_FILE" "${SECRETS_DESTINATION_FILE}"
    exit 0
fi

EXTERNAL_CONTRIBUTOR_RELEASE_MSG="External contributors should not need to perform a Release build"

# If the developer has a local secrets file, use it
if [ -f "$LOCAL_SECRETS_FILE" ]; then
    if [[ $CONFIGURATION == Release* ]]; then
      echo "error: You can't do a Release build when using local Secrets (from $LOCAL_SECRETS_FILE). $EXTERNAL_CONTRIBUTOR_RELEASE_MSG."
      exit 1
    fi

    echo "warning: Using local Secrets from $LOCAL_SECRETS_FILE. If you are an external contributor, this is expected and you can ignore this warning. If you are an internal contributor, make sure to use our shared credentials instead."
    echo "Applying Local Secrets"
    cp -v "$LOCAL_SECRETS_FILE" "${SECRETS_DESTINATION_FILE}"
    exit 0
fi

# None of the above secrets was found. Use the example secrets file as a last
# resort, unless building for Release.

COULD_NOT_FIND_SECRET_MSG="Could not find secrets file at ${SECRETS_DESTINATION_FILE}. This is likely due to the source secrets being missing from ${SECRETS_ROOT}"
INTERNAL_CONTRIBUTOR_MSG="If you are an internal contributor, run \`bundle exec fastlane run configure_apply\` to update your secrets and try again"
EXTERNAL_CONTRIBUTOR_MSG="If you are an external contributor, run \`bundle exec rake init:oss\` to set up and use your own credentials"

case $CONFIGURATION in
  Release*)
    # There are two release configurations: Release and Release-Alpha.
    # Since they all start with "Release", we can use a
    # pattern to check for them.
    echo "error: $COULD_NOT_FIND_SECRET_MSG. Cannot continue Release build. $INTERNAL_CONTRIBUTOR_MSG. $EXTERNAL_CONTRIBUTOR_RELEASE_MSG."
    exit 1
    ;;
  *)
    echo "warning: $COULD_NOT_FIND_SECRET_MSG. Falling back to $EXAMPLE_SECRETS_FILE. In a Release build, this would be an error. $INTERNAL_CONTRIBUTOR_MSG. $EXTERNAL_CONTRIBUTOR_MSG."
    echo "Applying Example Secrets"
    cp -v "$EXAMPLE_SECRETS_FILE" "${SECRETS_DESTINATION_FILE}"
    ;;
esac

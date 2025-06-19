#!/bin/bash -e

source $HELPER_SCRIPTS/install.sh

download_url=$(resolve_github_release_asset_url "nektos/act" "contains(\"act_Linux_x86_64.tar.gz\")" "latest")
archive_path=$(download_with_retry "$download_url")

tar -xzf "$archive_path" -C "/usr/local/bin" act

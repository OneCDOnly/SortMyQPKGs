#!/usr/bin/env bash

package_name=SortMyQPKGs
main_path=~/scripts/nas/$package_name

[[ -d $main_path ]] || exit

release_build=$(grep '^QPKG_VER=' $main_path/qpkg.cfg | cut -d '"' -f2)
asset_pathfile=$main_path/build/${package_name}_${release_build}.qpkg

[[ -e $asset_pathfile ]] || exit

git tag "v${release_build}"
git push --tags

gh release create "v${release_build}" --generate-notes "$asset_pathfile"

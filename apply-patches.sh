#!/bin/bash

set -e

patches="$(readlink -f -- $1)"

for project in $(cd $patches/patches; echo *);do
	p="$(tr _ / <<<$project |sed -e 's;platform/;;g')"
	[ "$p" == build ] && p=build/make
	#repo sync -l --force-sync $p || continue
	pushd $p
	git clean -fdx; git reset --hard
	for patch in $patches/patches/$project/*.patch;do
		#Check if patch is already applied
		echo "Processing patch $patch in $project ------------"
		echo "dry run"
		if patch -f -p1 --dry-run -R < $patch ;then
			echo "patch already applied, skipping..."
			continue
		fi

		if git apply --check $patch;then
			echo "applying patch $patch"
			if git am $patch
			then
				echo patch $patch successfully installed
			fi
		elif patch -f -p1 --dry-run < $patch ;then
			echo inside second dry run
			#This will fail
			git am $patch || true
			patch -f -p1 < $patch
			git add -u
			echo continuing am....
			git am --continue
		else
			echo "Failed applying $patch *******************"
		fi
	done
	popd
done


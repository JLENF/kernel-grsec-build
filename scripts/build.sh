#!/bin/bash

DEBUG=false
os_id=$(grep ^ID= /etc/os-release)
os_version=$(grep ^VERSION_ID= /etc/os-release)
filename=""
wget_args=""

# config debug pipe
if [ "${DEBUG}" == "false" ]; then
    PIPE="&>/dev/null"
else
    PIPE=""
fi

check_pre_requisites () {
	# check if version of kernel is parsed in podman command
	if [[ -z $version ]]; then
			echo "[kernel-grsec-build] - Version not found, set it with -e parameter"
			echo "[kernel-grsec-build] - Example: -e version=5.15"
			exit 1
	fi
	# check if .config file exists
	if [[ ! -f /scripts/.config ]]; then
		echo "[kernel-grsec-build] - .config file not found"
		echo "[kernel-grsec-build] - Please save the .config file in the /scripts directory"
		echo "[kernel-grsec-build] - You can get it with command: cp /boot/config-$(uname -r) scripts/.config"
		exit 1
	fi
}

check_or_download_patch () {
	# checking if the patch exists locally
	local_patch=$(ls /scripts/grsecurity-3.1-$version* 2>/dev/null | wc -l)
	if [[ $local_patch > 1 ]]; then
		echo "[kernel-grsec-build] - ERROR! There is more than one patch file for version 5.15 in local directory, only one version of the patch is needed."
	elif [[ $local_patch = 0 ]]; then
		# check if username and password are parsed
		if [[ -z $username ]] || [[ -z $password ]]; then
			echo "[kernel-grsec-build] - Subscription username and password not provided, set with the -e parameter"
			echo "[kernel-grsec-build] - Example: -e username=YOURUSERNAME -e password=YOURPASSWORD"
			echo "[kernel-grsec-build] - If you do not have it, check at https://grsecurity.net/purchase"
			exit 1
		fi
		# download patch from grsecurity.net
		echo "[kernel-grsec-build] - Searching for kernel patch: $version"
		curl -s https://grsecurity.net/download -o /tmp/grsecurity.txt
		download_link=$(grep -E -o -m1 'download-(beta-restrict|restrict)\/download-redirect.php\?file=grsecurity-3.1-'"$version"'.[0-9]+-[0-9]{12}\.patch' /tmp/grsecurity.txt  |head -n1)
		if [[ -z $download_link ]]; then
			echo "[kernel-grsec-build] - Download link not found, check in grsecurity.net/download"
			exit 1
		else
			filename=$(echo $download_link | cut -d'=' -f2)
			echo "[kernel-grsec-build] - Checking if username and password have a valid subscription"
			# check if server return 401 - authorization failed
			curl -skI https://$username:$password@grsecurity.net/$download_link -o /tmp/curl.txt
			check_auth=$(cat /tmp/curl.txt |grep ^HTTP/1.1)
			location_link=$(cat /tmp/curl.txt |grep ^Location: |awk '{print $2}')
			if [[ $check_auth =~ "401" ]]; then
				echo "[kernel-grsec-build] - Authentication error, you need a valid subscription"
				echo "[kernel-grsec-build] - If you do not have it, check at https://grsecurity.net/purchase"
				exit 1
			elif [[ $check_auth =~ "302" ]]; then
				echo "[kernel-grsec-build] - Downloading: grsecurity.net$location_link"
				# remove \r (CR) at end $location_link
				wget "https://$username:$password@grsecurity.net/${location_link%$'\r'}" -q $wget_args -O /tmp/$filename
				wget "https://$username:$password@grsecurity.net/${location_link%$'\r'}.sig" -q $wget_args -O /tmp/$filename.sig
				echo -n "[kernel-grsec-build] - Checking GPG signature.. "
							# gpg --yes -o ./download_latest_patch.gpg --dearmor ./download_latest_patch.asc
				gpg --no-default-keyring --keyring /scripts/download_latest_patch.gpg --verify /tmp/$filename.sig &>/dev/null
				if [[ $? = 0 ]]; then
					echo "- OK"
				else
					echo "- ERROR"
					exit 1
				fi
			else
				echo "[kernel-grsec-build] - Unknown error. Check if grsecurity.net is online"
				exit 1
			fi
		fi
	else
		echo "[kernel-grsec-build] - Using local patch"
	fi
}

download_kernel () {
	version_kernel=$(echo $filename |cut -d'-' -f3)
	major_kernel=$(echo $version_kernel |cut -c1)
	echo "[kernel-grsec-build] - Downloading kernel $version_kernel"
	cd /tmp
	wget https://cdn.kernel.org/pub/linux/kernel/v$major_kernel.x/linux-$version_kernel.tar.xz -q $wget_args -O /tmp/linux-$version_kernel.tar.xz
	tar -xf linux-$version_kernel.tar.xz
}

preparing_patch () {
	echo "[kernel-grsec-build] - Applying patch"
	cd /tmp/linux-$version_kernel
	patch -p1 < /tmp/$filename
	sed -ri '/CONFIG_SYSTEM_TRUSTED_KEYS/s/=.+/=""/g' /scripts/.config
	scripts/config --disable CONFIG_MAXSMP 
	scripts/config --set-val CONFIG_NR_CPUS_RANGE_BEGIN 256
	scripts/config --set-val CONFIG_NR_CPUS_RANGE_END 256
	scripts/config --set-val CONFIG_NR_CPUS_DEFAULT 256
	scripts/config --set-val CONFIG_NR_CPUS 256	
}

create_pkg (){
	echo "[kernel-grsec-build] - Creating built package"
	cd /tmp/linux-$version_kernel
	cp /scripts/.config .config
	#yes '' |make oldconfig
	make olddefconfig
	if [[ $os_id =~ "rocky" ]] || [[ $os_id =~ "centos" ]]; then
		# check if variable pkgname is parsed, to change name of generated files
		echo "grsec_$pkgname" > /tmp/linux-$version_kernel/localversion-grsec
		# built RPM packages
		make -j$(nproc --all) rpm-pkg
	elif [[ $os_id =~ "debian" ]] || [[ $os_id =~ "ubuntu" ]]; then
		# check if variable pkgname is parsed, to change name of generated files
		echo "grsec-$pkgname" > /tmp/linux-$version_kernel/localversion-grsec
		# built DEB packages
		make bindeb-pkg -j$(nproc --all)
	fi
}

end_message (){
	if [[ $? == 0 ]]; then
	if [[ $os_id =~ "debian" ]] || [[ $os_id =~ "ubuntu" ]]; then
		cp /tmp/*.deb /root/rpmbuild/
	fi
		echo "[kernel-grsec-build] - Successfully completed"
		echo "[kernel-grsec-build] - Check the packages in the directory: built_packages."
	else
		echo "[kernel-grsec-build] - ERROR in build"
		echo "[kernel-grsec-build] - Active debug flag and check logs"
	fi
}

# MAIN 
check_pre_requisites
# checking the operating system version to download necessary packages
if [[ $os_id =~ "rocky" ]] || [[ $os_id =~ "centos" ]]; then
	echo "[kernel-grsec-build] - CentOS / RockyLinux"
	echo "[kernel-grsec-build] - Downloading the necessary packages"
	eval yum update -y $PIPE
	eval yum install -y vim wget dnf lftp yum-plugin-changelog $PIPE
	eval dnf groupinstall -y "'Development Tools'" $PIPE
	eval dnf install xz patch -y $PIPE
	eval dnf install -y gcc-plugin-devel ncurses-devel openssl-devel elfutils-libelf-devel hmaccalc zlib-devel binutils-devel openssl $PIPE
	# if OS is Centos7, install updated gcc
	if [[ $os_id =~ "centos" ]] && [[ $os_version =~ "7" ]]; then
		echo "[kernel-grsec-build] - Installing tools for Centos7"
		eval yum install -y centos-release-scl $PIPE
		eval yum install -y devtoolset-7 devtoolset-7-gcc-plugin-devel python-docutils $PIPE
		source /opt/rh/devtoolset-7/enable
	fi
	if [[ $os_id =~ "rocky" ]] ; then
		wget_args="--show-progress"
		if [[ $os_version =~ "8." ]] ; then
			echo "[kernel-grsec-build] - Installing tools for Rockylinux8"
			eval dnf install -y gcc-toolset-11 gcc-toolset-11-gcc-plugin-devel python3-docutils openssl-devel bc rsync $PIPE 
			source /opt/rh/gcc-toolset-11/enable
		elif [[ $os_version =~ "9." ]] ; then
			echo "[kernel-grsec-build] - Installing tools for Rockylinux9"
			eval dnf install -y gcc-toolset-12 gcc-toolset-12-gcc-plugin-devel openssl-devel bc rsync $PIPE 
			source /opt/rh/gcc-toolset-12/enable
		fi
	fi
	check_or_download_patch
	download_kernel
	preparing_patch
	create_pkg
	end_message
elif [[ $os_id =~ "debian" ]] || [[ $os_id =~ "ubuntu" ]]; then
	echo "[kernel-grsec-build] - Debian / Ubuntu"
	echo "[kernel-grsec-build] - Downloading the necessary packages"
	eval apt-get update -y $PIPE
	eval apt-get install -y curl gpg vim wget rsync kmod cpio lsb-release $PIPE
	eval apt-get install -y build-essential libncurses5-dev libelf-dev libssl-dev gcc-8-plugin-dev flex bison bc $PIPE
	eval apt-get install build-essential linux-source bc kmod cpio flex libncurses5-dev libelf-dev libssl-dev dwarves bison -y $PIPE
	if [[ $os_id =~ "ubuntu" ]] && [[ $os_version =~ "20.04" ]] || [[ $os_id =~ "debian" ]] && [[ $os_version =~ "11" ]]; then
		echo "[kernel-grsec-build] - Installing tools for Ubuntu20.04"
		eval apt-get install -y gcc-10-plugin-dev $PIPE
		update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 10
		update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 10
		update-alternatives --install /usr/bin/cc cc /usr/bin/gcc 30
		update-alternatives --set cc /usr/bin/gcc
		update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 30
		update-alternatives --set c++ /usr/bin/g++
	fi
	check_or_download_patch
	download_kernel
	preparing_patch
	create_pkg
	end_message
fi
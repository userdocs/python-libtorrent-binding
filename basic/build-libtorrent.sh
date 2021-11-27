#!/usr/bin/env bash
#
# https://git.io/JXDOJ
#
# shellcheck disable=SC1091,SC2034
#
# docker run -it -w /root -v ~/build:/root ubuntu:focal /bin/bash -c 'apt update && apt install -y curl && curl -sL git.io/JXDOJ | bash -s boost_v= build_d= libtorrent_b= cxxstd= libtorrent= python_b= python_v= lto= crypto= system_crypto='
#
# docker run -it -w /root -v ~/build:/root alpine:latest /bin/ash -c 'apk update && apk add bash curl ncurses && curl -sL git.io/JXDOJ | bash -s boost_v= build_d= libtorrent_b= cxxstd= libtorrent= python_b= python_v= lto= crypto= system_crypto='
#
# ./build-libtorrent.sh boost_v= build_d= libtorrent_b= cxxstd= libtorrent= python_b= python_v= lto= crypto= system_crypto=
#
set -a
#
#  If these are unset they default
#
green="$(tput setaf 2)"
yellow="$(tput setaf 3)"
# blue="$(tput setaf 4)"
magenta="$(tput setaf 5)"
cyan="$(tput setaf 6)"
end="$(tput sgr0)"

for setting in "${@}"; do
	export "${setting?}"
done

what_id="$(source /etc/os-release && printf "%s" "${ID}")"                             # Get the main platform name, for example: debian, ubuntu or alpine
what_version_codename="$(source /etc/os-release && printf "%s" "${VERSION_CODENAME}")" # Get the codename for this this OS. Note, Alpine does not have a unique codename.

[[ -z "${python_v}" ]] && python_v="python3"
[[ "${python_v}" -eq '2' ]] && python_v="python2"
[[ "${python_v}" -eq '3' ]] && python_v="python3"
[[ "${what_version_codename}" =~ ^(stretch|bionic)$ && "${python_v}" == 'python2' ]] && python_v="python"
[[ "${what_version_codename}" =~ ^(alpine)$ && "${python_v}" == 'python3' ]] && pipnumpy=("py3-pip" "py3-numpy")

# Defaults are set here
boost_v="${boost_v:-77}"                   # boost_v= set the boost version using just 74/75/76/77
build_d="$(pwd)/${build_d:-lt-build}"      # build_d= set the build directory - default is lt-build relative to the container /root
install_d="${build_d}-completed"           # install_d= set the completed directory based of the build dir name
libtorrent_b="${libtorrent_b:-RC_2_0}"     # libtorrent_b= set the libtorrent branch to use - default is RC_2_0
cxxstd="${cxxstd:-17}"                     # cxxstd= set the cxx standard 11/14/17 - default is 17
libtorrent=${libtorrent:-yes}              # libtorrent= built libtorrent yes/no - default is yes
python_b="${python_b:-yes}"                # python_b= build the python binding yes/no - default is yes
python_v="${python_v:-python_v}"           # python_v= set the python version 2/3 - default is 3
crypto="${crypto:-openssl}"                # crypto= set wolfssl as alternative to openssl (default)
system_crypto="${system_crypto:-no}"       # system_crypto= use system libs [yes] or git latest release [no]
CXXFLAGS=("-std=c++${cxxstd:-17}" "-fPIC") # CXXFLAGS= Set some basic CXXFLAGS

[[ -n "${lto}" ]] && lto="lto=on" || lto="" # set values for boost the build dir and the liborrent branch - default is null . On or null are the options

if [[ "$(id -un)" = 'root' ]]; then
	if [[ $what_id =~ ^(debian|ubuntu)$ ]]; then
		printf '\n%s\n\n' "${green} Update env and install core deps${end}"
		DEBIAN_FRONTEND="noninteractive"
		TZ="Europe/London"
		#
		apt-get update
		apt-get upgrade -y
		#
		printf '%s\n' "LC_ALL=en_GB.UTF-8" "LANG=en_GB.UTF-8" "LANGUAGE=en_GB.UTF-8" > /etc/default/locale
		source /etc/default/locale
		#
		apt-get install -y locales
		sed 's|# en_GB.UTF-8 UTF-8|en_GB.UTF-8 UTF-8|g' -i /etc/locale.gen
		locale-gen
		#
		apt-get install -y build-essential dh-autoreconf curl pkg-config git perl "${python_v}" "${python_v}-dev" zlib1g-dev libssl-dev dh-autoreconf # install the deps
	elif [[ ${what_id} =~ ^(alpine)$ ]]; then
		printf '\n%s\n\n' "${green} Update env and install core deps${end}"
		apk update
		apk upgrade
		apk fix
		apk add build-base curl pkgconf autoconf automake libtool git perl "${python_v}" "${python_v}-dev" "${pipnumpy[@]}" linux-headers libffi-dev openssl-dev openssl-libs-static zlib-dev jpeg-dev
	fi
fi

printf '\n%s\n\n' "${green} Values being used:${end}"
printf '%s\n\n' " boost_v=1.${boost_v}.0${end}"
printf '%s\n\n' " build_d=${build_d}${end}"
printf '%s\n\n' " libtorrent_b=${libtorrent_b}${end}"
printf '%s\n\n' " cxxstd=${cxxstd}${end}"
printf '%s\n\n' " libtorrent=${libtorrent}${end}"
printf '%s\n\n' " python_b=${python_b}${end}"
printf '%s\n\n' " python_v=$("${python_v}" -c "import sys; print(sys.version_info[0])")${end}"
printf '%s\n\n' " ${lto:-lto=off}${end}"
printf '%s\n\n' " crypto=${crypto} ${end}${end}"
printf '%s\n\n' " system_crypto=${system_crypto} ${end}${end}"
printf '%s\n\n' " gcc version : $(gcc -dumpversion) ${end}${end}"

if [[ "${crypto}" == 'wolfssl' && "${system_crypto}" == 'no' ]]; then
	printf '%s\n\n' "${green} Download and bootstrap ${magenta}wolfssl${end}"
	wolfssl_github_tag="${wolfssl_github_tag:-$(grep -Eom1 'v([0-9.]+?)-stable$' <(curl -sL "https://github.com/wolfSSL/wolfssl/tags"))}"
	[[ -d "${build_d}/wolfssl" ]] && rm -rf "${build_d}/wolfssl"
	git clone --no-tags --single-branch --branch "${wolfssl_github_tag}" --shallow-submodules --recurse-submodules --depth 1 "https://github.com/wolfSSL/wolfssl.git" "${build_d}/wolfssl"
	cd "${build_d}/wolfssl" || exit
	./autogen.sh
	./configure --enable-static --disable-shared --enable-asio --enable-sni --enable-nginx "${CXXFLAGS[@]}"
	make -j"$(nproc)"
	crypto_array=("crypto=wolfssl" "wolfssl-lib=${build_d}/wolfssl/src/.libs" "wolfssl-include=${build_d}/wolfssl")
	printf '\n%s\n\n' "${green} Download and bootstrap ${magenta}boost_1_${boost_v}_0${end}"
fi

if [[ "${crypto}" == 'wolfssl' && "${system_crypto}" == 'yes' ]]; then
	crypto_array=("crypto=wolfssl" "wolfssl-include=/usr/include" "wolfssl-lib/usr/lib/$(arch)-linux-gnu")
	printf '%s\n\n' "${green} Download and bootstrap ${magenta}boost_1_${boost_v}_0${end}"
fi

if [[ "${crypto}" == 'openssl' && "${system_crypto}" == 'no' ]]; then
	printf '%s\n\n' "${green} Download and bootstrap ${magenta}openssl${end}"
	openssl_github_tag="${openssl_github_tag:-$(git ls-remote -q -t --refs https://github.com/openssl/openssl.git | awk '/openssl/{sub("refs/tags/", "");sub("(.*)(v6|rc|alpha|beta)(.*)", ""); print $2 }' | awk '!/^$/' | sort -rV | head -n1)}"
	[[ -d "${build_d}/openssl" ]] && rm -rf "${build_d}/openssl"
	git clone --no-tags --single-branch --branch "${openssl_github_tag}" --shallow-submodules --recurse-submodules --depth 1 "https://github.com/openssl/openssl" "${build_d}/openssl"
	cd "${build_d}/openssl" || exit
	./config --prefix="${build_d}" --openssldir="/etc/ssl" threads no-shared no-dso no-comp "${CXXFLAGS[@]}"
	make -j"$(nproc)"
	crypto_array=("crypto=openssl" "openssl-lib=${build_d}/openssl" "openssl-include=${build_d}/openssl/include")
	printf '\n%s\n\n' "${green} Download and bootstrap ${magenta}boost_1_${boost_v}_0${end}"
fi

if [[ "${crypto}" == 'openssl' && "${system_crypto}" == 'yes' ]]; then
	crypto_array=("crypto=openssl" "openssl-include=/usr/include" "openssl-lib=/usr/lib/$(arch)-linux-gnu")
	printf '%s\n\n' "${green} Download and bootstrap ${magenta}boost_1_${boost_v}_0${end}"
fi

if [[ ! -f "${build_d}/boost_1_${boost_v}_0/b2" ]]; then
	curl -sNLk "https://boostorg.jfrog.io/artifactory/main/release/1.${boost_v}.0/source/boost_1_${boost_v}_0.tar.gz" --create-dirs -o "${build_d}/boost_1_${boost_v}_0.tar.gz"
	tar xf "${build_d}/boost_1_${boost_v}_0.tar.gz" -C "${build_d}"
	cd "${build_d}/boost_1_${boost_v}_0/" || exit
	"${build_d}/boost_1_${boost_v}_0/bootstrap.sh"
else
	printf '%s\n' "${yellow} Skipping - we have already downloaded: ${magenta}boost_1_${boost_v}_0${end}"
fi

printf '\n%s\n\n' "${green} Configure ${cyan}BOOST_BUILD_PATH ${green}to locate our headers${end}"
#
export BOOST_BUILD_PATH="${build_d}/boost_1_${boost_v}_0" # once boost is bootstrapped and b2 is built you only need to set this for b2 + libtorrent.
#
printf '%s\n\n' "${green} Configure boost env via ${cyan}user-config.jam${end}"
#
echo "using gcc : : ;" > "$HOME/user-config.jam" # Create this file for b2: -dumpversion may give return a bad result outside a debian based systems
#
printf '%s\n\n' "${green} Git clone libtorrent ${magenta}${libtorrent_b}${end}"
#
[[ -d "${build_d}/libtorrent" ]] && rm -rf "${build_d}/libtorrent"
git clone --single-branch --branch "${libtorrent_b}" --shallow-submodules --recurse-submodules --depth 1 https://github.com/arvidn/libtorrent "${build_d}/libtorrent"
#
cd "${build_d}/libtorrent" || exit
#
if [[ "${libtorrent:-no}" == yes ]]; then
	printf '\n%s\n\n' "${green} Build libtorrent ${libtorrent_b}${end}"
	#
	"${build_d}/boost_1_${boost_v}_0/b2" -j"$(nproc)" address-model="$(getconf LONG_BIT)" "${lto}" optimization=speed cxxstd="${cxxstd}" variant=release dht=on encryption=on "${crypto_array[@]}" i2p=on extensions=on threading=multi link=static boost-link=static install --prefix="${install_d}"
	#
	printf '\n%s\n\n' "${green} Files are located at: ${cyan}${install_d}/lib${end}"
else
	printf '\n%s\n\n' "${yellow} Skipping libtorrent${end}"
fi
#
if [[ "${python_b}" == yes ]]; then
	printf '%s\n\n' "${green} Configure boost python env via ${cyan}user-config.jam${end}"
	#
	python_major="$("${python_v}" -c "import sys; print(sys.version_info[0])")"
	python_minor="$("${python_v}" -c "import sys; print(sys.version_info[1])")"
	#
	echo "using python : ${python_major}.${python_minor} : /usr/bin/python${python_major}.${python_minor} : /usr/include/python${python_major}.${python_minor} : /usr/lib/python${python_major}.${python_minor} ;" >> "$HOME/user-config.jam"
	#
	cd "${build_d}/libtorrent/bindings/python" || exit
	#
	printf '%s\n\n' "${green} Build libtorrent ${libtorrent_b} pything bindings${end}"
	#
	"${build_d}/boost_1_${boost_v}_0/b2" -j"$(nproc)" address-model="$(getconf LONG_BIT)" fpic=on "${lto}" optimization=speed cxxstd="${cxxstd}" variant=release dht=on encryption=on "${crypto_array[@]}" i2p=on extensions=on threading=multi libtorrent-link=static boost-link=static install_module python-install-scope=user
	#
	printf '\n%s\n\n' "${green} Python binding file is located at: ${cyan}$("${python_v}" -c "import site; import sys; sys.stdout.write(site.USER_SITE)")/libtorrent.so${end}"
	printf '%s\n\n' "${green} Python binding version is: ${cyan}$("${python_v}" -c "import libtorrent; print(libtorrent.version)")${end}"
else
	printf '%s\n\n' "${yellow} Skipping libtorrent python binding${end}"
fi

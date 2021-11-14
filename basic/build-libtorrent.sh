#!/usr/bin/env bash
#
# https://git.io/JXDOJ
#
# shellcheck disable=SC1091,SC2034
#
# docker run -it -w /root -e "LANG=en_GB.UTF-8" -v $HOME/build:/root ubuntu:bionic /bin/bash -c 'apt update && apt install -y curl && curl -sL git.io/JXDOJ | bash -s boost_v=76 build_d=yes libtorrent_b= cxxstd=14 libtorrent= python_b= python_v= lto=on'
#
# ./build-libtorrent.sh boost_v= build_d= libtorrent_b= cxxstd= libtorrent= python_b= python_v= lto= crypto=
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
#
for setting in "${@}"; do
	"${setting?}"
done
#
[[ -z "${python_v}" ]] && python_v="python3"
[[ "${python_v}" -eq '2' ]] && python_v="python2"
[[ "${python_v}" -eq '3' ]] && python_v="python3"
[[ "$(source /etc/os-release && printf '%s' "$VERSION_CODENAME")" =~ (stretch|bionic) && "${python_v}" == 'python2' ]] && python_v="python"
#
## Defaults are set here
#
LANG="en_GB.UTF-8"                     # docker specific env
LANGUAGE="en_GB.UTF-8"                 # docker specific env
LC_ALL="en_GB.UTF-8"                   # docker specific env
DEBIAN_FRONTEND="noninteractive"       # docker specific env
TZ="Europe/London"                     # docker specific env
boost_v="${boost_v:-77}"               # set the boost version using just 74/75/76/77
build_d="$(pwd)/${build_d:-lt-build}"  # set the build directory - default is 3 lt-build relative to the container /root
install_d="${build_d}-completed"       # set the completed directory based of the build dir name
libtorrent_b="${libtorrent_b:-RC_2_0}" # set the libtorrent branch to use - default is RC_2_0
cxxstd="${cxxstd:-17}"                 # set the cxx standard 11/14/17 - default is 17
libtorrent=${libtorrent:-yes}          # built libtorrent yes/no - default is yes
python_b="${python_b:-yes}"            # build the python binding yes/no - default is yes
python_v="${python_v:-python_v}"       # set the python version 2/3 - default is 3
crypto="${crypto:-openssl}"            # set wolfssl as alternative to opensll (default)
CXXFLAGS="-std=c++${cxxstd:-17} -fPIC" # Set some basic CXXFLAGS
#
[[ -n "${lto}" ]] && lto="lto=on" || lto="" # set values for boost the build dir and the liborrent branch - default is null . On or null are the options
#
printf '\n%s\n\n' "${green} Update env and install core deps${end}"
#
apt-get update
apt-get upgrade -y
apt-get install -y build-essential curl pkg-config git perl "${python_v}" "${python_v}-dev" zlib1g-dev libssl-dev # install the deps
#
printf '\n%s\n\n' "${green} Values being used ${cyan}:${yellow} Boost version = 1.${boost_v}.0 ${cyan}:${yellow} build dir = ${build_d} ${cyan}:${yellow} libtorrent branch = ${libtorrent_b} ${cyan}:${yellow} CXX standard = ${cxxstd} ${cyan}:${yellow} libtorrent=${libtorrent} ${cyan}:${yellow} python_b=${python_b} ${cyan}:${yellow} python_v=$("${python_v}" -c "import sys; print(sys.version_info[0])") ${cyan}:${yellow} ${lto:-lto=off} ${cyan}:${yellow} crypto=${crypto} ${end}"
#
if [[ "${crypto}" == 'wolfssl' ]]; then
	printf '%s\n\n' "${green} Download and bootstrap ${magenta}wolfssl${end}"
	wolfssl_github_tag="$(grep -Eom1 'v([0-9.]+?)-stable$' <(curl -sL "https://github.com/wolfSSL/wolfssl/tags"))"
	git clone --no-tags --single-branch --branch "${wolfssl_github_tag}" --shallow-submodules --recurse-submodules --depth 1 "https://github.com/wolfSSL/wolfssl.git" "${build_d}/wolfssl"
	cd "${build_d}/wolfssl" || exit
	./autogen.sh
	./configure --enable-static --disable-shared --enable-asio --enable-sni --enable-nginx CXXFLAGS="$CXXFLAGS"
	make -j"$(nproc)"
	crypto=("crypto=wolfssl" "wolfssl-lib=${build_d}/wolfssl/src/.libs" "wolfssl-include=${build_d}/wolfssl")
	printf '\n%s\n\n' "${green} Download and bootstrap ${magenta}boost_1_${boost_v}_0${end}"
else
	crypto=("crypto=openssl")
	printf '%s\n\n' "${green} Download and bootstrap ${magenta}boost_1_${boost_v}_0${end}"
fi
#
if [[ ! -f "${build_d}/boost_1_${boost_v}_0/b2" ]]; then
	curl -sNLk "https://boostorg.jfrog.io/artifactory/main/release/1.${boost_v}.0/source/boost_1_${boost_v}_0.tar.gz" --create-dirs -o "${build_d}/boost_1_${boost_v}_0.tar.gz"
	tar xf "${build_d}/boost_1_${boost_v}_0.tar.gz" -C "${build_d}"
	cd "${build_d}/boost_1_${boost_v}_0/" || exit
	"${build_d}/boost_1_${boost_v}_0/bootstrap.sh"
else
	printf '%s\n' "${yellow} Skipping - we have already downloaded: ${magenta}boost_1_${boost_v}_0${end}"
fi
#
printf '\n%s\n\n' "${green} Configure BOOST_BUILD_PATH to locate our headers${end}"
#
export BOOST_BUILD_PATH="${build_d}/boost_1_${boost_v}_0" # once boost is bootstrapped and b2 is built you only need to set this for b2 + libtorrent.
#
printf '%s\n\n' "${green} Configure boost env via ${cyan}user-config.jam${end}"
#
echo "using gcc : $(gcc -dumpversion) : g++-$(g++ -dumpversion) ;" > "$HOME/user-config.jam" # Create this file for b2: -dumpversion may give return a bad result outside a debian based systems
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
	"${build_d}/boost_1_${boost_v}_0/b2" -j"$(nproc)" address-model="$(getconf LONG_BIT)" "${lto}" optimization=speed cxxstd="${cxxstd}" variant=release dht=on encryption=on "${crypto[@]}" i2p=on extensions=on threading=multi link=static boost-link=static install --prefix="${install_d}"
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
	"${build_d}/boost_1_${boost_v}_0/b2" -j"$(nproc)" address-model="$(getconf LONG_BIT)" fpic=on "${lto}" optimization=speed cxxstd="${cxxstd}" variant=release dht=on encryption=on "${crypto[@]}" i2p=on extensions=on threading=multi libtorrent-link=static boost-link=static install_module python-install-scope=user
	#
	printf '\n%s\n\n' "${green} Python binding file is located at: ${cyan}$("${python_v}" -c "import site; import sys; sys.stdout.write(site.USER_SITE)")/libtorrent.so${end}"
	printf '%s\n\n' "${green} Python binding version is: ${cyan}$("${python_v}" -c "import libtorrent; print(libtorrent.version)")${end}"
else
	printf '%s\n\n' "${yellow} Skipping libtorrent python binding${end}"
fi

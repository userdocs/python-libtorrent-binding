#! /usr/bin/env bash
#
# Copyright 2020 by userdocs and contributors
#
# SPDX-License-Identifier: Apache-2.0
#
# @author - userdocs
#
# @contributors IceCodeNew, brettpetch
#
# @credits - https://gist.github.com/notsure2
#
# shellcheck disable=SC2034,SC2086,SC1091 # Why are these checks excluded?
#
# https://github.com/koalaman/shellcheck/wiki/SC2034 There a quite a few variables defined by combining other variables that mean nothing on their own. This behavior is intentional and the warning can be skipped.
#
# https://github.com/koalaman/shellcheck/wiki/SC2086 There are a few examples where this is exactly what I want to happen, like when expanding the curl proxy arguments.
#
# https://github.com/koalaman/shellcheck/wiki/SC1091 I am sourcing /etc/os-release for some variables. It's not available to shell check to source and it's a safe file so we can skip this
#
# Script Formatting - https://marketplace.visualstudio.com/items?itemName=foxundermoon.shell-format
#
## Script start ###############################################################
set -ea # https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html

unset PARAMS build_dir skip_delete GITHUB_TAG libtorrent_github_tag git_proxy curl_proxy test_build modules_test crypto_type # Make sure this array of variables is reset to null when the script is loaded.

script_full_path=$(readlink -f "${BASH_SOURCE[0]}")
script_parent_path="${script_full_path##*/}"
script_basename="${script_full_path%/*}"
libtorrent_version='2.0' # Set this here so it is easy to see and change

#
## Color me up Scotty #########################################################
#
cr="\e[31m" && clr="\e[91m" # [c]olor[r]ed     && [c]olor[l]ight[r]ed
cg="\e[32m" && clg="\e[92m" # [c]olor[g]reen   && [c]olor[l]ight[g]reen
cy="\e[33m" && cly="\e[93m" # [c]olor[y]ellow  && [c]olor[l]ight[y]ellow
cb="\e[34m" && clb="\e[94m" # [c]olor[b]lue    && [c]olor[l]ight[b]lue
cm="\e[35m" && clm="\e[95m" # [c]olor[m]agenta && [c]olor[l]ight[m]agenta
cc="\e[36m" && clc="\e[96m" # [c]olor[c]yan    && [c]olor[l]ight[c]yan
#
tb="\e[1m" && td="\e[2m" && tu="\e[4m" && tn="\n" # [t]ext[b]old && [t]ext[d]im && [t]ext[u]nderlined && [t]ext[n]ewline
#
cend="\e[0m" # [c]olor[end]
#################################################################################################################################################
# Color me up Scotty - define some color values to use as variables in the scripts.
#################################################################################################################################################
color_red="\e[31m" color_red_light="\e[91m"
color_green="\e[32m" color_green_light="\e[92m"
color_yellow="\e[33m" color_yellow_light="\e[93m"
color_blue="\e[34m" color_blue_light="\e[94m"
color_magenta="\e[35m" color_magenta_light="\e[95m"
color_cyan="\e[36m" color_cyan_light="\e[96m"

text_bold="\e[1m" text_dim="\e[2m" text_underlined="\e[4m" text_blink="\e[5m" text_newline="\n"

unicode_red_circle="\e[31m\U2B24\e[0m" unicode_red_light_circle="\e[91m\U2B24\e[0m"
unicode_green_circle="\e[32m\U2B24\e[0m" unicode_green_light_circle="\e[92m\U2B24\e[0m"
unicode_yellow_circle="\e[33m\U2B24\e[0m" unicode_yellow_light_circle="\e[93m\U2B24\e[0m"
unicode_blue_circle="\e[34m\U2B24\e[0m" unicode_blue_light_circle="\e[94m\U2B24\e[0m"
unicode_magenta_circle="\e[35m\U2B24\e[0m" unicode_magenta_light_circle="\e[95m\U2B24\e[0m"
unicode_cyan_circle="\e[36m\U2B24\e[0m" unicode_cyan_light_circle="\e[96m\U2B24\e[0m"
unicode_grey_circle="\e[37m\U2B24\e[0m" unicode_grey_light_circle="\e[97m\U2B24\e[0m"

color_end="\e[0m"
#######################################################################################################################################################
# Check we are on a supported OS and release.
#######################################################################################################################################################
get_os_info() {
	# shellcheck source=/dev/null
	if source /etc/os-release &> /dev/null; then
		printf "%s" "${!1%_*}" # the expansion part is specific to the Alpine VERSION_ID format 1.2.3_alpha but won't break anything in Debian based format e.g. 12/24.04
	else
		printf "%s" "unknown" # This will make the script exit on the version check and provide useful reason.
	fi
}

os_id="$(get_os_info ID)"                                    # Get the ID for this OS.
os_version_codename="$(get_os_info VERSION_CODENAME)"        # Get the codename for this OS. Note, Alpine does not have a unique codename.
os_version_id="$(get_os_info VERSION_ID)"                    # Get the version number for this codename, for example: 10, 20.04, 3.12.4
[[ ${os_id} =~ ^(alpine)$ ]] && os_version_codename="alpine" # If alpine, set the codename to alpine. We check for min v3.10 later with codenames.

if [[ ${os_id} =~ ^(debian|ubuntu)$ ]]; then
	# dpkg --print-architecture give amd64/arm64 and arch gives x86_64/aarch64
	os_arch="$(dpkg --print-architecture)"
elif [[ ${os_id} =~ ^(alpine)$ ]]; then
	# apk --print-arch gives x86_64/aarch64
	os_arch="$(apk --print-arch)"
fi

# Check against allowed codenames or if the codename is alpine version greater than 3.10
if [[ ! ${os_version_codename} =~ ^(alpine|trixie|noble)$ ]] || [[ ${os_version_codename} =~ ^(alpine)$ && "$(apk version -t "${os_version_id}" "3.18")" == "<" ]]; then
	printf '\n%b\n\n' " ${unicode_red_circle} ${color_yellow} This is not a supported OS. There is no reason to continue.${color_end}"
	printf '%b\n\n' " id: ${text_dim}${color_yellow_light}${os_id}${color_end} codename: ${text_dim}${color_yellow_light}${os_version_codename}${color_end} version: ${text_dim}${color_red_light}${os_version_id}${color_end}"
	printf '%b\n\n' " ${unicode_yellow_circle} ${text_dim}These are the supported platforms${color_end}"
	printf '%b\n' " ${color_magenta_light}Debian${color_end} - ${color_blue_light}trixie${color_end}"
	printf '%b\n' " ${color_magenta_light}Ubuntu${color_end} - ${color_blue_light}noble${color_end}"
	printf '%b\n\n' " ${color_magenta_light}Alpine${color_end} - ${color_blue_light}3.18${color_end} ${text_dim}or greater${color_end}"
	exit
fi
#######################################################################################################################################################
# Revised dependency check function
#######################################################################################################################################################
declare -A core_deps deps_delete modules_delete

if [[ $os_id =~ (debian|ubuntu) ]]; then
	core_deps["build-essential"]="false"
	core_deps["pkg-config"]="false"
	core_deps["python3-pip"]="false"
	core_deps["python3-numpy"]="false"
	# For docker deploys to not get prompted to set the timezone.
	export DEBIAN_FRONTEND="noninteractive" && TZ="Europe/London"
elif [[ $os_id == "alpine" ]]; then
	core_deps["build-base"]="false"
	core_deps["pkgconf"]="false"
	core_deps["py3-pip"]="false"
	core_deps["py3-numpy"]="false"
	core_deps["linux-headers"]="false"
	core_deps["libffi-dev"]="false"
	core_deps["zlib-dev"]="false"
	core_deps["jpeg-dev"]="false"
	# core_deps["openssl-dev"]="false"
fi
# consistent package names on Debian/Ubuntu and Alpine
core_deps["autoconf"]="false"
core_deps["automake"]="false"
core_deps["bison"]="false"
core_deps["cmake"]="false"
core_deps["curl"]="false"
core_deps["git"]="false"
core_deps["libtool"]="false"
core_deps["perl"]="false"
core_deps["python3"]="false"
core_deps["python3-dev"]="false"
# Tools that don't need to be installed if they are available in the PATH to use for basic tests
declare -A test_tools
test_tools["curl"]="false"
test_tools["git"]="false"
test_tools["python3"]="false"

declare -A modules_install
modules_install["all"]="true"
modules_install["install_deluge"]="true"
modules_install["openssl"]="true"
modules_install["wolfssl"]="true"
modules_install["boost"]="true"
modules_install["libtorrent"]="true"

# Define our list privilege checks
privileges_required["root"]="false"
privileges_required["sudo"]="false"

pkgman=()
command_test_tool=()
command_install_deps=()
command_update_upgrade_os=()
install_simulation=()

_privilege_check() {
	printf '\n%b\n' " ${unicode_blue_light_circle} ${text_bold}Checking: ${color_red_light}available privileges${color_end}"

	if [[ "$(id -un 2> /dev/null)" == 'root' ]]; then
		printf '\n%b\n' " $unicode_green_circle ${color_red_light}root${color_end}"
		privileges_required["root"]="true"
		command_privilege=()
	else
		printf '\n%b\n' " $unicode_red_circle ${color_red_light}root${color_end}"
	fi

	if sudo -n true &> /dev/null; then
		printf '%b\n' " $unicode_green_circle ${color_red_light}sudo${color_end}"
		privileges_required["sudo"]="true"
		command_privilege=("sudo")
	else
		printf '%b\n' " $unicode_red_circle ${color_red_light}sudo${color_end}"
	fi

	if [[ $os_id =~ (debian|ubuntu) ]]; then
		pkgman+=("${command_privilege[@]}" "dpkg" "-s")
		command_test_tool+=("${command_privilege[@]}" "dpkg" "-s")
		command_install_deps+=("${command_privilege[@]}" "apt-get" "install" "-y")
		command_update_upgrade_os+=("${command_privilege[@]}" "bash" "-c" "apt-get update && apt-get upgrade -y && apt-get autoremove -y")
		install_simulation+=("${command_privilege[@]}" "apt" "install" "--simulate")
	elif [[ $os_id == "alpine" ]]; then
		pkgman+=("${command_privilege[@]}" "apk" "info" "-e" "--no-cache")
		command_test_tool+=("${command_privilege[@]}" "apk" "info" "-e" "--no-cache")
		command_install_deps+=("${command_privilege[@]}" "apk" "add" "-u" "--no-cache")
		command_update_upgrade_os+=("${command_privilege[@]}" "bash" "-c" "apk add --no-cache && apk upgrade --no-cache")
		install_simulation+=("${command_privilege[@]}" "apk" "add" "--simulate" "--no-cache")
	fi
}

_check_tools_work() {
	local tool="${1}"
	local tool_type="${2}"
	local run_type="${3}"
	_command_test() {
		if [[ $tool_type == "test_tools" ]]; then
			command -v "${tool}"
		elif [[ $tool_type == "build_tools" ]]; then
			"${command_test_tool[@]}" "${tool}"
		fi
	}

	if _command_test &> /dev/null; then
		if [[ ${run_type} != "silent" ]]; then
			printf "%b\n" " $unicode_green_circle ${color_yellow}${1}${color_end}"
		fi
		return 0
	else
		if [[ ${run_type} != "silent" ]]; then
			printf "%b\n" " $unicode_red_circle ${color_yellow}${1}${color_end}"
		fi
		return 1
	fi
}

_check_dependency_status() {
	local silent="${1:-}"

	filtered_params=()
	for pparam in "$@"; do
		if [[ $pparam != "silent" ]]; then
			filtered_params+=("$pparam")
		fi
	done && unset pparam

	[[ ${silent} != 'silent' ]] && printf '\n%b\n\n' " ${unicode_blue_light_circle} ${text_bold}Checking: ${color_yellow}test${color_end}"

	while IFS= read -r tt; do
		if _check_tools_work "${tt}" "test_tools" "${silent}"; then
			test_tools["${tt}"]="true"
			unset "build_tools[${tt}]"
		fi
	done < <(printf '%s\n' "${!test_tools[@]}" | sort)

	# remove packages in the deps_delete arrays from the core_deps array

	for dd in "${!deps_delete[@]}"; do
		unset "core_deps[${dd}]"
	done && unset dd

	# remove test_tools packages in the test_tools array from the core_deps array if available via command -v
	for tt in "${!test_tools[@]}"; do
		if [[ ${test_tools[$tt]} == "true" ]]; then
			unset "core_deps[$tt]"
		fi
	done && unset tt

	[[ ${silent} != 'silent' ]] && printf '\n%b\n\n' " ${unicode_blue_light_circle} ${text_bold}Checking: ${color_magenta}core${color_end}"

	# This checks over the core_deps array for the OS specified dependencies to see if they are installed
	while IFS= read -r pkg; do

		pkgman() { "${pkgman[@]}" "${pkg}"; }

		if pkgman > /dev/null 2>&1; then
			[[ ${silent} != 'silent' ]] && printf '%b\n' " ${unicode_green_circle} ${color_magenta}${pkg}${color_end}"
			core_deps["${pkg}"]="true"
		else
			if [[ -n ${pkg} ]]; then
				[[ ${silent} != 'silent' ]] && printf '%b\n' " ${unicode_red_circle} ${color_magenta}${pkg}${color_end}"
				core_deps_sorted+=("$pkg")
				core_deps["${pkg}"]="false"
			fi
		fi
	done < <(printf '%s\n' "${!core_deps[@]}" | sort)
}

_privilege_check

_check_dependency_status "${@}"

if [[ ${privileges_required["root"]} == "true" || ${privileges_required["sudo"]} == "true" ]]; then

	if [[ ${core_deps[*]} =~ "false" ]]; then
		printf '\n%b\n\n' " $unicode_blue_circle ${color_blue}Info:${color_end} $script_full_path"

		if ! "${install_simulation[@]}" "${!test_tools[@]}" &> /dev/null; then
			printf '%b\n' " $unicode_blue_circle ${color_blue_light}$script_parent_path${color_end} ${color_magenta}update${color_end} ------------ update host - package simulation failed"
		fi

		if [[ ${test_tools[*]} =~ "false" ]]; then
			printf '%b\n' " $unicode_blue_circle ${color_blue_light}$script_parent_path${color_end} ${color_yellow}install_test${color_end} ------ installs minimum required tools to run tests"
		fi

		printf '%b\n' " $unicode_blue_circle ${color_blue_light}$script_parent_path${color_end} ${color_magenta}install_core${color_end} ------ installs required build tools to use script"

		if ! "${install_simulation[@]}" "${!test_tools[@]}" &> /dev/null; then
			printf '%b\n' " $unicode_blue_circle ${color_blue_light}$script_parent_path${color_end} ${color_green_light}bootstrap_deps${color_end} ---- ${color_magenta}update${color_end} + ${color_yellow}install_test${color_end} + ${color_magenta}install_core${color_end}"
		else
			printf '%b\n' " $unicode_blue_circle ${color_blue_light}$script_parent_path${color_end} ${color_green_light}bootstrap_deps${color_end} ---- ${color_yellow}install_test${color_end} + ${color_magenta}install_core${color_end}"
		fi
	fi
else
	printf '\n%b\n\n' " $unicode_red_circle ${color_yellow}Warning${color_end}: No root or sudo privileges detected. Nothing to do"
	printf '%b\n' " $unicode_red_circle ${color_yellow}Warning${color_end}: ${color_magenta}test_tools${color_end} are required to access basic features of the script.${color_end}"
fi

if [[ ${test_tools[*]} =~ "false" ]]; then
	printf '\n%b\n' " $unicode_red_circle ${color_yellow}Warning:${color_end} Missing required ${color_magenta}test_tools${color_end}"
fi

if [[ ${core_deps[*]} =~ "false" ]]; then
	printf '\n%b\n' " $unicode_red_circle ${color_yellow}Warning:${color_end} Missing required components of ${color_magenta}install_core${color_end}"
fi

# Check if user is able to install the dependencies, if yes then do so, if no then exit.
if [[ ${privileges_required["root"]} == "true" || ${privileges_required["sudo"]} == "true" ]]; then

	_update_os() {
		printf '\n%b\n\n' " ${unicode_blue_light_circle} ${color_green}Updating${color_end}"
		"${command_update_upgrade_os[@]}"
		# needed to use these functions in the -bs flags
		declare -fx _update_os
	}

	_install_tools() {
		# We don't want to run update every time. Only if the the installation command cannot work without an update being run first
		if ! "${install_simulation[@]}" "${!test_tools[@]}" &> /dev/null; then _update_os; fi

		if [[ ${1} == "test" ]]; then
			printf '\n%b\n\n' " ${unicode_blue_light_circle}${color_green} Installing test dependencies${color_end}"
		elif [[ ${1} == "core" ]]; then
			printf '\n%b\n\n' " ${unicode_blue_light_circle}${color_green} Installing core dependencies${color_end}"
		fi

		if [[ ${1} == "test" ]]; then
			for tt in "${!test_tools[@]}"; do
				if [[ $tt != "root" && $tt != "sudo" ]]; then
					"${command_install_deps[@]}" "$tt"
				fi
			done && unset tt
		fi

		if [[ ${1} == "core" ]]; then
			"${command_install_deps[@]}" "${core_deps_sorted[@]}"
		fi
		# needed to use these functions in the -bs flags
		declare -fx _install_tools
	}

	if [[ $* =~ ([[:space:]]|^)(update)([[:space:]]|$) ]]; then
		_update_os
	fi

	if [[ $* =~ ([[:space:]]|^)(install_test)([[:space:]]|$) ]]; then
		_install_tools test
	fi

	if [[ $* =~ ([[:space:]]|^)(install_core)([[:space:]]|$) ]]; then
		_install_tools core
	fi

	if [[ $* =~ ([[:space:]]|^)(bootstrap_deps)([[:space:]]|$) ]]; then
		_update_os
		_install_tools core
	fi

	_check_dependency_status silent "${@}"
else
	printf '\n%b\n' " ${text_bold}Please request or install the missing core dependencies before using this script${color_end}"
	if [[ ${os_id} =~ ^(alpine)$ ]]; then
		printf '\n%b\n\n' " ${color_red_light}apk add${color_end} ${core_deps_sorted[*]}"
	elif [[ ${os_id} =~ ^(debian|ubuntu)$ ]]; then
		printf '\n%b\n\n' " ${color_red_light}apt-get install -y${color_end} ${core_deps_sorted[*]}"
	fi
	exit
fi

if [[ ${test_tools[*]} =~ "false" ]]; then
	printf '\n'
	exit
fi

for mi in "${!modules_install[@]}"; do
	if [[ ${filtered_params[*]} =~ ([[:space:]]|^)${mi}([[:space:]]|$) ]]; then
		if [[ ${core_deps[*]} =~ "false" ]]; then
			printf '\n'
			exit
		fi
	fi
done && unset mi

if [[ ! ${core_deps[*]} =~ "false" ]]; then
	printf '\n%b\n' " ${unicode_green_circle}${text_bold} Dependencies: All checks passed, continuing to build${color_end}"
fi

declare -a modules_excluded=("debug" "update" "install_test" "install_core" "bootstrap_deps")
for arg in "${@}"; do
	if [[ ! ${modules_excluded[*]} =~ ([[:space:]]|^)(${arg})([[:space:]]|$) ]]; then
		declare -ga filtered_check_dependency_args+=("$arg")
	fi
done

set -- "${filtered_check_dependency_args[@]}"
#####################################################################################################################################################
# This function sets some compiler flags globally - b2 settings are set in the ~/user-config.jam - this is set in the installation_modules function
#####################################################################################################################################################
custom_flags_set() {
	CFLAGS="-std=c++${cxxstd:-20} -fPIC -O3 -march=native -pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS"
	CPPFLAGS="-I$include_dir -fPIC -O3 -march=native"
	CXXFLAGS="-pipe -fstack-clash-protection -fstack-protector-strong -fno-plt -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3 -D_GLIBCXX_ASSERTIONS"
	LDFLAGS="-L$lib_dir -gz -Wl,-O1,--as-needed,--sort-common,-z,now,-z,pack-relative-relocs,-z,relro"
}
#####################################################################################################################################################
# This function creates our _curl function that we use throughout this script.
#####################################################################################################################################################
_curl() {
	if [[ -z $curl_proxy ]]; then
		"$(type -P curl)" -sNL4fq --connect-timeout 5 --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
	else
		"$(type -P curl)" -sNL4fq --connect-timeout 5 --retry 5 --retry-delay 10 --retry-max-time 60 --proxy-insecure ${curl_proxy} "$@"
	fi
}

github_latest_version() {
	# Argument expects the author/repo format that has a vlaid release url.
	# e.g. boostorg/boost
	if [[ -n $1 ]]; then
		url_effective="$(_curl -SI -o /dev/null -w "%{url_effective}" "https://github.com/${1}/releases/latest")"
		if [[ ${url_effective##*/} == "releases" ]]; then
			printf '%s\n' "error:github_latest_version"
		else
			printf '%s\n' "${url_effective##*/}"
		fi
	else
		printf '%s\n' "error:github_latest_version"
	fi
}
#####################################################################################################################################################
# This function sets the build and installation directory. If the argument -b is used to set a build directory that directory is set and used.
# If nothing is specified or the switch is not used it defaults to the hard-coded ~/libtorrent-python
#####################################################################################################################################################
set_build_directory() {
	if [[ -n $build_dir ]]; then
		if [[ $build_dir =~ ^/ ]]; then
			install_dir="$build_dir"
		else
			install_dir="${HOME}/${build_dir}"
		fi
	else
		install_dir="$HOME/libtorrent-python"
	fi
	## Set lib and include directory paths based on install path.
	include_dir="$install_dir/include"
	lib_dir="$install_dir/lib"
	#
	# Define some build specific variables
	PATH="$install_dir/bin:$HOME/bin${PATH:+:${PATH}}"
	PKG_CONFIG_PATH="$lib_dir/pkgconfig"
}
#####################################################################################################################################################
# boost url function
#####################################################################################################################################################
boost_url() {
	boost_version="${boost_github_tag/boost-/}"

	local boost_asset_type="release"
	local boost_archiveio_asset="${boost_github_tag//[-\.]/_}"

	if [[ ${boost_github_tag} =~ \.beta ]]; then
		boost_asset_type="beta"
		boost_archiveio_asset="${boost_archiveio_asset/_beta/_b}"
	fi

	local boost_url_array=(
		"https://github.com/boostorg/boost/releases/download/${boost_github_tag}/${boost_github_tag}-b2-nodocs.tar.xz"
		"https://archives.boost.io/${boost_asset_type}/${boost_github_tag#boost-}/source/${boost_archiveio_asset}.tar.gz"
	)

	for url in "${boost_url_array[@]}"; do
		if _curl -I "${url}" &> /dev/null; then
			boost_url_status="200"
			boost_url="${url}"
			break
		else
			boost_url_status="403"
			error_status="boost_url"
		fi
	done
}

#####################################################################################################################################################
# This function is where we set your URL that we use with other functions.
#####################################################################################################################################################
set_module_urls() {
	openssl_github_tag="$(github_latest_version "openssl/openssl")"
	openssl_url="https://github.com/openssl/openssl/archive/${openssl_github_tag}.tar.gz"

	wolfssl_github_tag="$(github_latest_version "wolfSSL/wolfssl")"
	wolfssl_github_url="https://github.com/wolfSSL/wolfssl.git"

	if [[ -z ${boost_github_tag} ]]; then
		boost_github_tag="$(github_latest_version boostorg/boost)"
	fi

	boost_url

	boost_github_url="https://github.com/boostorg/boost.git"

	libtorrent_github_url="https://github.com/arvidn/libtorrent.git"

	if [[ $valid_libtorrent_github_tag == "yes" ]]; then
		libtorrent_github_tag="$libtorrent_github_tag"
	elif [[ $libtorrent_github_tag == "lm_master" ]]; then
		libtorrent_github_tag="RC_${libtorrent_version//./_}"
	else
		libtorrent_github_tag=$(github_latest_version "arvidn/libtorrent")
	fi

	ltconfig_version="$(github_latest_version "ratanakvlun/deluge-ltconfig")"
	ltconfig_url="https://github.com/ratanakvlun/deluge-ltconfig/releases/latest/download/ltConfig-${ltconfig_version#v}.egg"
}
#####################################################################################################################################################
# This function determines which crypto is default (openssl) and what to do if wolfssl is selected.
#####################################################################################################################################################
set_libtorrent_crypto() {
	pb_libtorrent_crypto=("crypto=openssl" "openssl-lib=$install_dir/openssl-$openssl_github_tag" "openssl-include=$install_dir/openssl-$openssl_github_tag/include")
	ssl_module="openssl"

	if [[ $crypto_type == 'wolfssl' ]]; then
		if [[ $libtorrent_github_tag =~ ^(RC_2_[0-9]|v2[\.0-9]{2,3}[\.0-9]{2,2})$ ]]; then
			pb_libtorrent_crypto=("crypto=wolfssl" "wolfssl-lib=$install_dir/wolfssl/src/.libs" "wolfssl-include=$install_dir/wolfssl")
			ssl_module="wolfssl"
		else
			echo
			echo -e "${cy} wolfssl only works with libtorrent v2 or above${cend}"
			echo
			echo -e "${td} This script defaults to the v1.2 latest version${cend}"
			echo
			echo -e "${cg} ~/${script_parent_path}${cend} ${clm}all${cend} ${clb}-c${cend} ${clm}wolfssl${cend} ${clb}-lt${cend} ${cc}RC_2_0${cend}"
			echo
			exit
		fi
	fi
}
#####################################################################################################################################################
# This function sets some default values we use but whose values can be overridden by certain flags
#####################################################################################################################################################
set_default_values() {
	working_dir="$(printf "%s" "$(pwd <(dirname "$0"))")"                 # Get the full path to the scripts location to use with setting some path related variables.
	modules=("all" "install_deluge" "${ssl_module}" "boost" "libtorrent") # Define our list of available modules in an array.
	scope="${scope:-user}"                                                # We can define the libtorrent installation settings for the b2 command here.
	if [[ $scope == 'none' ]]; then
		LIBTORRENT_INSTALL_DIR="" # Just use stage_module to copy the libtorrent.so to the completed directory.
	else
		LIBTORRENT_INSTALL_DIR="install_module python-install-scope=${scope}" # Use these commands to install the libtorrent.so.
	fi
	LIBTORRENT_INSTALL_MODULE="stage_module ${LIBTORRENT_INSTALL_DIR}" # We can define the libtorrent installation settings for the b2 command here.
}
#####################################################################################################################################################
# This function allows you to test the compiled libraries to make sure they work.
#####################################################################################################################################################
test_library_builds() {
	if [[ $test_build == 'yes' ]]; then

		installed_scope_system="$(python3 -c "import distutils.sysconfig; import sys; sys.stdout.write(distutils.sysconfig.get_python_lib())")/libtorrent.so"
		installed_scope_local="$(python3 -c "import site; import sys; sys.stdout.write(site.USER_SITE)")/libtorrent.so"
		installed_scope_none="$install_dir/completed/libtorrent.so"

		printf '\n'

		test_library() {
			if [[ ${1} == "${installed_scope_system}" || ${1} == "${installed_scope_local}" || ${1} == "${installed_scope_none}" ]]; then

				echo -e "libtorrent location${cend}${td}:${cend} ${cc}${1}${cend}${tn}"

				if [[ ${1} == "${installed_scope_none}" ]]; then
					cd "$install_dir/completed"
				fi

				if python3 -c "import libtorrent; print(libtorrent.version)" > /dev/null 2>&1; then
					echo -e " ${clb}Using python3${cend} - ${cy}libtorrent version${cend}${td}:${cend} ${cg}$(python3 -c "import libtorrent; print(libtorrent.version)")${cend}${tn}"
				else
					echo -e " ${cy}libtorrent.so found but not built with python3${cend}"
					echo
				fi
			fi
		}

		[[ -f ${installed_scope_system} ]] && test_library "${installed_scope_system}"
		[[ -f ${installed_scope_local} ]] && test_library "${installed_scope_local}"
		[[ -f ${installed_scope_none} ]] && test_library "${installed_scope_none}"

		if [[ ! -f ${installed_scope_system} && ! -f ${installed_scope_local} && ! -f ${installed_scope_none} ]]; then
			echo -e "Sorry, but I cannot find an installed libtorrent.so library."
			echo
			echo -e "${cy}If you used a custom build directory please provide that via the${cend} ${clb}-b${cend} ${cy}flag${cend}"
			echo
		fi
		exit
	fi
}
#####################################################################################################################################################
# This function verifies the module names from the array modules in the default values function.
#####################################################################################################################################################
installation_modules() {
	# Delete modules - using the modules_delete array to unset them from the modules_install array
	for md in "${!modules_delete[@]}"; do
		if [[ ${modules_delete["$md"]} == "true" ]]; then
			unset "modules_install[${md}]"
		fi
	done && unset md

	# For any modules params passed, test that they exist in the modules_install array or set modules_test to fail
	for passed_params in "${@}"; do
		if [[ ! ${!modules_install[*]} =~ ([[:space:]]|^)(${passed_params})([[:space:]]|$) ]]; then
			modules_test="fail"
		fi
	done
	unset passed_params

	# Activate all validated modules for installation and define some core variables.
	if [[ ${modules_test} != 'fail' && ${#} -ne '0' ]]; then
		if [[ ${*} =~ ([[:space:]]|^)all([[:space:]]|$) ]]; then
			for module in "${modules[@]}"; do
				eval "skip_${module}=no"
			done
		else
			for module in "${@}"; do
				eval "skip_${module}=no"
			done
		fi
		#
		# Create the directories we need.
		mkdir -p "$install_dir/logs"
		mkdir -p "$install_dir/completed"
		#
		## Set some python variables we need.
		python_major="$(python3 -c "import sys; print(sys.version_info[0])")"
		python_minor="$(python3 -c "import sys; print(sys.version_info[1])")"
		python_micro="$(python3 -c "import sys; print(sys.version_info[2])")"
		#
		python_short_version="${python_major}.${python_minor}"
		python_link_version="${python_major}${python_minor}"
		#
		echo -e "using gcc : : : <cxxflags>-std=c++${cxxstd:-20} ;${tn}using python : ${python_short_version} : /usr/bin/python${python_short_version} : /usr/include/python${python_short_version} : /usr/lib/python${python_short_version} ;" > "$HOME/user-config.jam"
		#
		## Echo the build directory.
		echo -e "${tn}${tb}Install Prefix${cend} : ${cg}$install_dir${cend}"
		#
		## Some basic help
		echo -e "${tn}${tb}Script help${cend} : ${cg}~/${script_parent_path} -h${cend}"
	else
		echo -e "${cr}${tn}One or more of the provided modules are not supported${cend}"
		echo -e "${tb}${tn}This is a list of supported modules${cend}"
		echo -e "${clm}${tn}${modules[*]}${tn}${cend}"
		exit
	fi
}
#####################################################################################################################################################
# This function will test to see if a Jamfile patch file exists via the variable patches_github_url for the tag used.
#####################################################################################################################################################
apply_patches() {
	[[ -d "$install_dir/patches" ]] && rm -rf "$install_dir/patches"

	[[ $libtorrent_github_tag =~ ^(libtorrent-1_1_[0-9]{1,2}|RC_1_1) ]] && libtorrent_patch_github_tag="RC_1_1"
	[[ $libtorrent_github_tag =~ ^(libtorrent-1_2_[0-9]{1,2}|RC_1_2|v1.2\.[0-9]{1,2})$ ]] && libtorrent_patch_github_tag="RC_1_2"
	[[ $libtorrent_github_tag =~ ^(RC_2_0|v2\.[0-9](\.[0-9]{1,2})?)$ ]] && libtorrent_patch_github_tag="RC_2_0"

	patches_github_url="https://raw.githubusercontent.com/userdocs/python-libtorrent-binding/master/patches/$libtorrent_patch_github_tag/Jamfile"

	if [[ "$(
		_curl "$patches_github_url" > /dev/null
		echo "$?"
	)" -ne '22' ]]; then
		_curl "$patches_github_url" -o "$install_dir/libtorrent/bindings/python/Jamfile"
	else
		_curl "https://raw.githubusercontent.com/arvidn/libtorrent/$libtorrent_patch_github_tag/bindings/python/Jamfile" -o "$install_dir/libtorrent/bindings/python/Jamfile"
	fi
}
#####################################################################################################################################################
# This function installs deluge and lt-config locally
#####################################################################################################################################################
install_deluge() {
	if [[ $os_id =~ ^(debian|ubuntu)$ ]]; then
		printf '\n%b\n\n' "${unicode_blue_circle} Installing deluge via pip"
		pip install --user deluge --break-system-packages
	elif [[ $os_id == "alpine" ]]; then
		printf '\n%b\n\n' "${unicode_blue_circle} Installing deluge via apk"
		"${command_install_deps[@]}" deluge
	fi

	for d in $(pgrep deluge); do kill -9 $d; done

	mkdir -p "$HOME/.config/deluge/plugins"
	_curl "$ltconfig_url" -o "$HOME/.config/deluge/plugins/ltConfig-${ltconfig_version}.egg"
	chmod 700 "$HOME/.config/deluge/plugins/ltConfig-${ltconfig_version}.egg"

	set +e # deluge-console plugin -e ltconfig is bugged and causes some error even though it works

	if [[ $os_id =~ ^(debian|ubuntu)$ ]]; then
		"$HOME/.local/bin/deluged"
		"$HOME/.local/bin/deluge-console" plugin -e ltconfig &> /dev/null
		"$HOME/.local/bin/deluge-web"
	elif [[ $os_id == "alpine" ]]; then
		deluged
		deluge-web
		deluge-console plugin -e ltconfig &> /dev/null
	fi

	if [[ $os_id =~ ^(debian|ubuntu)$ ]]; then binary_path="~/.local/bin/"; fi

	printf '%b\n\n' "${cg}${tn}The libtorrent python binding has been installed and started using these commands!${cend}"
	printf '%b\n' "${cc}${binary_path}deluged${cend}"
	printf '%b\n' "${cc}${binary_path}deluge-console plugin -e ltconfig${cend}"
	printf '%b\n\n' "${cc}${binary_path}deluge-web${cend}"

	exit
}
#####################################################################################################################################################
# This function is for downloading source code archives
#####################################################################################################################################################
download_file() {
	if [[ -n $1 ]]; then
		url_filename="${2}"
		[[ -n $3 ]] && subdir="/$3" || subdir=""
		github_tag_var="${1}_github_tag"
		echo -e "${tn}${cg}Installing $1${cend} ${!github_tag_var}${tn}"
		file_name="$install_dir/$1.tar.gz"
		[[ -f $file_name ]] && rm -rf "${install_dir:?}/$(tar tf "$file_name" | grep -Eom1 "(.*)[^/]")" "$file_name"
		_curl "${url_filename}" -o "$file_name"
		dir_to_move="${install_dir:?}/$(tar tf "$file_name" | grep -Eom1 "(.*)[^/]")"
		tar xf "$file_name" -C "$install_dir"
		mkdir -p "$install_dir/$(tar tf "$file_name" | head -1 | cut -f1 -d"/")${subdir}"
		cd "$install_dir/$(tar tf "$file_name" | head -1 | cut -f1 -d"/")${subdir}" || exit
	else
		echo
		echo "You must provide a filename name for the function - download_file"
		echo "It creates the name from the appname_github_tag variable set in the URL section"
		echo
		echo "download_file filename url"
		echo
		exit
	fi
}
#####################################################################################################################################################
# This function is for downloading git releases based on their tag.
#####################################################################################################################################################
download_folder() {
	if [[ -n $1 ]]; then
		github_tag="${1}_github_tag"
		url_github="${2}"
		[[ -n $3 ]] && subdir="/$3" || subdir=""
		echo -e "${tn}${cg}Installing $1${cend}${tn}"
		folder_name="$install_dir/$1"
		[[ -d $folder_name ]] && rm -rf "$folder_name"
		git ${git_proxy} clone --no-tags --single-branch --branch "${!github_tag}" --shallow-submodules --recurse-submodules -j"$(nproc)" --depth 1 "${url_github}" "${folder_name}"
		mkdir -p "${folder_name}${subdir}"
		cd "${folder_name}${subdir}" || exit
	else
		echo
		echo "You must provide a tag name for the function - download_folder"
		echo "It creates the tag from the appname_github_tag variable set in the URL section"
		echo
		echo "download_folder tagname url subdir"
		echo
		exit
	fi
}
#####################################################################################################################################################
# This function is for removing files and folders we no longer need
#####################################################################################################################################################
delete_function() {
	if [[ -n $1 ]]; then
		if [[ -z $skip_delete ]]; then
			[[ $2 == 'last' ]] && echo -e "${tn}${clr}Deleting $1 installation files and folders${cend}${tn}" || echo -e "${tn}${clr}Deleting $1 installation files and folders${cend}"
			#
			file_name="$install_dir/$1.tar.gz"
			folder_name="$install_dir/$1"
			[[ -f $file_name ]] && rm -rf {"${install_dir:?}/$(tar tf "$file_name" | grep -Eom1 "(.*)[^/]")","$file_name"}
			[[ -d $folder_name ]] && rm -rf "$folder_name"
			cd "$working_dir" || exit
		else
			[[ $2 == 'last' ]] && echo -e "${tn}${clr}Skipping $1 deletion${cend}${tn}" || echo -e "${tn}${clr}Skipping $1 deletion${cend}"
		fi
	else
		echo
		echo "The delete_function works in tandem with the application_name function"
		echo "Set the appname using the application_name function then use this function."
		echo
		echo "delete_function appname"
		echo
		exit
	fi
}
#####################################################################################################################################################
# This function sets the name of the application to be used with the functions download_file/folder and delete_function
#####################################################################################################################################################
application_name() {
	last_app_name="skip_$app_name"
	app_name="$1"
	app_name_skip="skip_$app_name"
	app_url="${app_name}_url"
	app_github_url="${app_name}_github_url"
}
#####################################################################################################################################################
# This function skips the deletion of the -n flag is supplied
#####################################################################################################################################################
application_skip() {
	if [[ $1 == 'last' ]]; then
		echo -e "${tn}Skipping ${clm}$app_name${cend} module installation${tn}"
	else
		echo -e "${tn}Skipping ${clm}$app_name${cend} module installation"
	fi
}
#####################################################################################################################################################
# This section controls our flags that we can pass to the script to modify some variables and behavior.
#####################################################################################################################################################
while (("$#")); do
	case "$1" in
		-b | --build-directory)
			build_dir="$2"
			shift 2
			;;
		-c | --crypto)
			if [[ ! $2 =~ ^(openssl|wolfssl)$ ]]; then
				echo
				echo -e "${cy}I don't know this crypto type. Valid options are${cend} ${clm}openssl${cend} ${cy}and${cend} ${clm}wolfssl${cend}"
				echo
				exit
			else
				crypto_type="$2"
			fi
			shift 2
			;;
		-n | --no-delete)
			skip_delete='yes'
			shift
			;;
		-lm | --libtorrent-master)
			libtorrent_github_tag='lm_master'
			shift
			;;
		-lt | --libtorrent-tag)
			if git ls-remote --exit-code "https://github.com/arvidn/libtorrent.git" -t "$2" > /dev/null 2>&1; then
				valid_libtorrent_github_tag="yes"
				libtorrent_github_tag="$2"

				if [[ ${libtorrent_github_tag} =~ ^(v1\.2\.|RC_1_2) ]]; then
					boost_github_tag="boost-1.86.0"
					boost_url
				fi

				echo
				echo -e "${cy}Libtorrent tag${cend} ${cg}$2${cend} ${cy}verified!${cend}"
			else
				echo
				echo -e "${cy}Sorry, that is not a valid libtorrent tag${cend}"
				echo
				exit
			fi
			shift 2
			;;
		-p | --proxy)
			git_proxy="-c http.sslVerify=false -c http.https://github.com.proxy=$2"
			curl_proxy="-x $2"
			shift 2
			;;
		-tb | --test-build)
			test_build='yes'
			shift
			;;
		-s | --scope)
			scope="${2:-user}"
			if [[ ! $scope =~ ^(none|user|system)$ ]]; then
				echo
				set_build_directory
				echo
				echo -e "${cy}Please specify ${cc}user${cend} ${cy}or${cend} ${cc}system${cend} ${cy}or${cend} ${cc}none${cend}. ${cy}The default is${cend} ${cc}user${cend}"
				echo
				echo -e "${cy}If you use ${cc}none${cend} ${cy}The library is only installed to:${cend}"
				echo
				echo -e "${cg}$install_dir/completed/libtorrent.so${cend}"
				echo
				exit
			fi
			shift 2
			;;
		-h | --help)
			printf '\n%b\n\n' "${tb}${tu}Here are a list of available options${cend}"
			printf '%b\n' " ${cg}Use:${cend} ${clb}-b${cend}  ${td}or${cend} ${clb}--build-directory${cend}   ${cy}Help:${cend} ${clb}-h-b${cend}  ${td}or${cend} ${clb}--help-build-directory${cend}"
			printf '%b\n' " ${cg}Use:${cend} ${clb}-c${cend}  ${td}or${cend} ${clb}--crypto${cend}            ${cy}Help:${cend} ${clb}-h-c${cend}  ${td}or${cend} ${clb}--help-crypto${cend}"
			printf '%b\n' " ${cg}Use:${cend} ${clb}-n${cend}  ${td}or${cend} ${clb}--no-delete${cend}         ${cy}Help:${cend} ${clb}-h-n${cend}  ${td}or${cend} ${clb}--help-no-delete${cend}"
			printf '%b\n' " ${cg}Use:${cend} ${clb}-lm${cend} ${td}or${cend} ${clb}--libtorrent-master${cend} ${cy}Help:${cend} ${clb}-h-lm${cend} ${td}or${cend} ${clb}--help-libtorrent-master${cend}"
			printf '%b\n' " ${cg}Use:${cend} ${clb}-lt${cend} ${td}or${cend} ${clb}--libtorrent-tag${cend}    ${cy}Help:${cend} ${clb}-h-lt${cend} ${td}or${cend} ${clb}--help-libtorrent-tag${cend}"
			printf '%b\n' " ${cg}Use:${cend} ${clb}-p${cend}  ${td}or${cend} ${clb}--proxy${cend}             ${cy}Help:${cend} ${clb}-h-p${cend}  ${td}or${cend} ${clb}--help-proxy${cend}"
			printf '%b\n' " ${cg}Use:${cend} ${clb}-tb${cend} ${td}or${cend} ${clb}--test-build${cend}        ${cy}Help:${cend} ${clb}-h-tb${cend} ${td}or${cend} ${clb}--help-test-build${cend}"
			printf '%b\n\n' " ${cg}Use:${cend} ${clb}-s${cend}  ${td}or${cend} ${clb}--scope${cend}             ${cy}Help:${cend} ${clb}-h-s${cend}  ${td}or${cend} ${clb}--help-scope${cend}"
			printf '%b\n\n' "${tb}${tu}Module specific help - flags are used with the modules listed here.${cend}"
			printf '%b\n\n' "${cg}Use:${cend} ${clm}all${cend} ${td}or${cend} ${clm}module-name${cend}         ${cy}Usage:${cend} ${cg}~/${script_parent_path}${cend} ${clm}all${cend}"

			printf '%b\n\n' "${tb}${tu}Here are a list of dependency specific modules${cend}"

			printf '%b\n' " ${clm}update${cend}${td} --------- ${cend}${td}update host - apt/apk update${cend}"
			printf '%b\n' " ${clm}install_test${cend}${td} --- ${cend}${td}Install test features dependencies${cend}"
			printf '%b\n' " ${clm}install_core${cend}${td} --- ${cend}${td}Install core build dependencies${cend}"
			printf '%b\n' " ${clm}bootstrap_deps${cend}${td} - ${cend}${td}update + install_test + install_core${cend}"
			printf '%b\n' " ${clm}install_deluge${cend}${td} - ${cend}${td}pip install deluge${cend}"

			printf '\n%b\n\n' "${tb}${tu}Here are a list of build specific modules${cend}"
			printf '%b\n' " ${clm}all${cend}${td} ----------- ${cend}${td}Install all modules - openssl boost libtorrent${cend}"
			printf '%b\n' " ${clm}openssl${cend}${td} ------- ${cend}${td}Install the openssl module${cend} ${cy}(default)${cend}"
			printf '%b\n' " ${clm}wolfssl${cend}${td} ------- ${cend}${td}Install the wolf module${cend} ${cy}(Libtorrent v2 only)${cend}"
			printf '%b\n' " ${clm}boost${cend}${td} --------- ${cend}${td}Download, extract and bootstrap the boost build files${cend}"
			printf '%b\n\n' " ${clm}libtorrent${cend}${td} ---- ${cend}${td}Build the libtorrent python binding${cend}"
			exit 1
			;;
		-h-b | --help-build-directory)
			echo
			echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
			echo
			echo -e " Default build location:${cc} $HOME/libtorrent-python${cend}"
			echo
			echo -e " ${clb}-b${cend} or ${clb}--build-directory${cend} to set the location of the build directory."
			echo
			echo -e " ${cy}Paths are relative to the script location. I recommend that you use a full path.${cend}"
			echo
			echo -e " ${td}Example:${cend} ${cg}~/${script_parent_path}${cend} ${clm}all${cend} ${td}- Will install all modules and build libtorrent to the default build location"${cend}
			echo
			echo -e " ${td}Example:${cend} ${cg}~/${script_parent_path}${cend} ${clm}all ${clb}-b${cend} \"\$HOME/build\"${cend} ${td}- Will specify a build directory and install all modules to that custom location${cend}"
			echo
			echo -e " ${td}Example:${cend} ${cg}~/${script_parent_path}${cend} ${clm}module${cend} ${td}- Will install a single module to the default build location${cend}"
			echo
			echo -e " ${td}Example:${cend} ${cg}~/${script_parent_path}${cend} ${clm}module${cend} ${clb}-b${cend} \"\$HOME/build\"${cend} ${td}- will specify a custom build directory and install a specific module use to that custom location${cend}"
			echo
			exit 1
			;;
		-h-c | --help-crypto)
			echo
			echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
			echo
			echo -e " Libtorrent v2 onwards supports using wolfssl instead of openssl"
			echo
			echo -e " ${td}This flag must be provided with arguments.${cend}"
			echo
			echo -e " ${clm}openssl${cend} (default and works with all versions)"
			echo
			echo -e " ${clm}wolfssl${cend}"
			echo
			echo -e " ${cy}You must use ${clb}-lt${cend}${cy} to set a v2 tag with wolfssl${cend}"
			echo
			echo -e " ${clb}-c${cend} ${clm}wolfssl${cend} ${clb}-lt${cend} ${cc}RC_2_0${cend}"
			echo
			exit 1
			;;
		-h-n | --help-no-delete)
			echo
			echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
			echo
			echo -e " Skip all delete functions for selected modules to leave source code directories behind."
			echo
			echo -e " ${td}This flag is provided with no arguments.${cend}"
			echo
			echo -e " ${clb}-n${cend}"
			echo
			exit 1
			;;
		-h-lm | --help-libtorrent-master)
			echo
			echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
			echo
			echo -e " Always use the master branch for ${cg}libtorrent-$libtorrent_version${cend}"
			echo
			echo -e " This master that will be used is: ${cg}RC_${libtorrent_version//./_}${cend}"
			echo
			echo -e " ${td}This flag is provided with no arguments.${cend}"
			echo
			echo -e " ${clb}-lm${cend}"
			echo
			exit 1
			;;
		-h-lt | --help-libtorrent-tag)
			echo
			echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
			echo
			echo -e " Use a provided libtorrent tag when cloning from github."
			echo
			echo -e " ${cy}You can use this flag with this help command to see the value if called before the help option.${cend}"
			echo
			echo -e " ${cg}~/${script_parent_path}${cend}${clb} -lt ${clc}12345${cend} ${clb}-h-lt${cend}"
			[[ -n $libtorrent_github_tag ]] && echo -e "${tn} This tag that will be used is: ${cg}$libtorrent_github_tag${cend}"
			echo
			echo -e " ${td}This flag must be provided with arguments.${cend}"
			echo
			echo -e " ${clb}-lt${cend} ${clc}v1.2.19${cend}"
			echo
			exit 1
			;;
		-h-p | --help-proxy)
			echo
			echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
			echo
			echo -e " Specify a proxy URL and PORT to use with curl and git${cend}"
			echo
			echo -e " ${clb}-p${cend} ${clc}https://proxy.com:12345${cend}"
			echo
			echo -e " ${cy}You can use this flag with this help command to see the value if called before the help option:${cend}"
			echo
			echo -e " ${cg}~/${script_parent_path}${cend} ${clb}-p${cend} ${clc}https://proxy.com:12345${cend} ${clb}-h-p${cend}"
			echo
			[[ -n $git_proxy ]] && echo -e " git proxy command: $git_proxy"
			[[ -n $curl_proxy ]] && echo -e " curl proxy command: $curl_proxy${tn}"
			exit 1
			;;
		-h-tb | --help-test-build)
			echo
			echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
			echo
			echo -e "Use this to test the compiled python binding."
			echo
			echo -e "${cy}If you used a custom build directory you will need to provide the location using the ${clb}-b${cend} ${cy}flag${cend}"
			echo
			echo -e "${td}This flag is provided with no arguments.${cend}"
			echo
			echo -e "${clb} -tb${cend}"
			echo
			exit 1
			;;
		-h-s | --help-scope)
			echo
			echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
			echo
			echo -e " Use this flag to define the b2 installation settings for the python binding"
			echo
			echo -e " ${cy}The default option is to install to the python user site.${cend}"
			echo
			echo -e " There are 3 options with user being the default scope"
			echo
			echo -e " ${clc}user${cend}   - default ${td}- installs to the user's ~/.local python site directory.${cend}"
			echo -e " ${clc}system${cend} ${td}- installs to the system lib dir.${cend}"
			echo -e " ${clc}none${cend}   ${td}- Install only to the /completed directory in the build directory.${cend}"
			echo
			echo -e " ${clb}-s${cend} ${clc}user${cend}"
			echo -e " ${clb}-s${cend} ${clc}system${cend}"
			echo -e " ${clb}-s${cend} ${clc}none${cend}"
			echo
			exit 1
			;;
		--) # end argument parsing
			shift
			break
			;;
		-*) # unsupported flags
			echo -e "${tn}Error: Unsupported flag ${cr}$1${cend} - use ${cg}-h${cend} or ${cg}--help${cend} to see the valid options${tn}" >&2
			exit 1
			;;
		*) # preserve positional arguments
			PARAMS="$PARAMS $1"
			shift
			;;
	esac
done
#
eval set -- "$PARAMS" # Set positional arguments in their proper place.
#####################################################################################################################################################
# Use our functions
#####################################################################################################################################################
set_build_directory                                                            # see functions
set_module_urls                                                                # see functions
set_libtorrent_crypto                                                          # see functions
set_default_values                                                             # see functions
test_library_builds                                                            # see functions
installation_modules "$@"                                                      # see functions
[[ ${*} =~ ([[:space:]]|^)"install_deluge"([[:space:]]|$) ]] && install_deluge # see functions
#####################################################################################################################################################
# openssl installation
#####################################################################################################################################################
application_name openssl

if [[ ${!app_name_skip:-yes} == 'no' || $1 == "$app_name" ]]; then
	custom_flags_set
	download_file "$app_name" "${!app_url}"

	./config --prefix="$install_dir" --libdir="lib" threads no-shared no-dso no-comp CXXFLAGS="$CXXFLAGS" CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" 2>&1 | tee "$install_dir/logs/$app_name.log.txt"
	make -j"$(nproc)" 2>&1 | tee -a "$install_dir/logs/$app_name.log.txt"
else
	application_skip
fi
#####################################################################################################################################################
# wolf installation
#####################################################################################################################################################
application_name wolfssl
#
if [[ ${!app_name_skip:-yes} == 'no' || $1 == "$app_name" ]]; then
	custom_flags_set
	download_folder "$app_name" "${!app_github_url}"
	#
	./autogen.sh
	./configure --help > "$install_dir/config-help.txt"
	./configure --prefix="$install_dir" --enable-static --disable-shared --enable-asio --enable-sni --enable-nginx CXXFLAGS="$CXXFLAGS" CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" 2>&1 | tee "$install_dir/logs/$app_name.log.txt"
	make -j"$(nproc)" 2>&1 | tee -a "$install_dir/logs/$app_name.log.txt"
else
	application_skip
fi
#####################################################################################################################################################
# boost libraries install
#####################################################################################################################################################
application_name boost

if [[ ${!app_name_skip:-yes} == 'no' ]] || [[ $1 == "$app_name" ]]; then
	custom_flags_set

	[[ -d "$install_dir/boost" ]] && delete_function "$app_name"

	if [[ $boost_url_status -eq '200' ]]; then
		download_file "$app_name" "$boost_url"
		mv -f "${dir_to_move}" "$install_dir/boost"
		cd "$install_dir/boost" || exit
	fi

	if [[ $boost_url_status -eq '403' ]]; then
		download_folder "$app_name" "${!app_github_url}"
	fi

	"$install_dir/boost/bootstrap.sh" 2>&1 | tee "$install_dir/logs/$app_name.log.txt"
	"$install_dir/boost/b2" headers
else
	application_skip
fi
#####################################################################################################################################################
# libtorrent install
#####################################################################################################################################################
application_name libtorrent

if [[ ${!app_name_skip:-yes} == 'no' ]] || [[ $1 == "$app_name" ]]; then
	if [[ ! -d "$install_dir/boost" ]]; then
		echo -e "${tn}${clr}Warning${cend} - You must install the boost module before you can use the libtorrent module"
	else
		custom_flags_set
		download_folder "$app_name" "${!app_github_url}"

		BOOST_ROOT="$install_dir/boost"
		BOOST_INCLUDEDIR="$install_dir/boost"
		BOOST_BUILD_PATH="$install_dir/boost"

		apply_patches # see functions

		cd "$folder_name/bindings/python" || exit

		"$install_dir/boost/b2" -j"$(nproc)" "${pb_libtorrent_crypto[@]}" address-model="$(getconf LONG_BIT)" cxxstd="${cxxstd:-20}" fpic=on dht=on encryption=on i2p=on extensions=on variant=release threading=multi libtorrent-link=static boost-link=static cxxflags="$CXXFLAGS" cflags="$CPPFLAGS" linkflags="$LDFLAGS -lgcov --coverage" ${LIBTORRENT_INSTALL_MODULE} 2>&1 | tee "$install_dir/logs/libtorrent.log.txt"

		[[ -f "$install_dir/libtorrent/bindings/python/libtorrent.so" ]] && cp "$install_dir/libtorrent/bindings/python/libtorrent.so" "$install_dir/completed/libtorrent.so"

		delete_function "${ssl_module}"
		delete_function boost
		delete_function "${app_name}" last
	fi
else
	application_skip last
fi
#####################################################################################################################################################
# We are all done so now exit
#####################################################################################################################################################
exit

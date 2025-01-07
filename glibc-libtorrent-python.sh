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
#
set -e -a # https://www.gnu.org/software/bash/manual/html_node/The-Set-Builtin.html
#
libtorrent_version='2.0' # Set this here so it is easy to see and change
#
unset PARAMS BUILD_DIR SKIP_DELETE GITHUB_TAG LIBTORRENT_GITHUB_TAG GIT_PROXY CURL_PROXY TEST_BUILD MODULES_TEST GET_NUMPY CRYPTO_TYPE # Make sure this array of variables is reset to null when the script is loaded.
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
#
#####################################################################################################################################################
# This function sets some compiler flags globally - b2 settings are set in the ~/user-config.jam - this is set in the installation_modules function
#####################################################################################################################################################
custom_flags_set() {
        CXXFLAGS="-std=c++${cxxstd:-17} -fPIC -O3 -march=native"
        CPPFLAGS="-I$include_dir -O3 -march=native"
        LDFLAGS="-L$lib_dir"
}
#####################################################################################################################################################
# This function creates our curl function that we use throughout this script.
#####################################################################################################################################################
curl() {
        if [[ -z "$CURL_PROXY" ]]; then
                "$(type -P curl)" -sNL4fq --connect-timeout 5 --retry 5 --retry-delay 10 --retry-max-time 60 "$@"
        else
                "$(type -P curl)" -sNL4fq --connect-timeout 5 --retry 5 --retry-delay 10 --retry-max-time 60 --proxy-insecure ${CURL_PROXY} "$@"
        fi
}

github_latest_version() {
    # Argument expects the author/repo format
    # e.g. swizzin/swizzin
    repo=$1
    curl -fsSLI -o /dev/null -w %{url_effective} https://github.com/${repo}/releases/latest | grep -o '[^/]*$'
}

#####################################################################################################################################################
# This function sets the build and installation directory. If the argument -b is used to set a build directory that directory is set and used.
# If nothing is specified or the switch is not used it defaults to the hard-coded ~/libtorrent-python
#####################################################################################################################################################
set_build_directory() {
        if [[ -n "$BUILD_DIR" ]]; then
                if [[ "$BUILD_DIR" =~ ^/ ]]; then
                        install_dir="$BUILD_DIR"
                else
                        install_dir="${HOME}/${BUILD_DIR}"
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
# This function is where we set your URL that we use with other functions.
#####################################################################################################################################################
set_module_urls() {
        openssl_github_tag="$(github_latest_version "openssl/openssl")"
        openssl_url="https://github.com/openssl/openssl/archive/${openssl_github_tag}.tar.gz"
        #
        wolfssl_github_tag="$(github_latest_version "wolfSSL/wolfssl")"
        wolfssl_github_url="https://github.com/wolfSSL/wolfssl.git"
        #
        boost_version="$(github_latest_version "boostorg/boost")"
        [[ "$LIBTORRENT_GITHUB_TAG" =~ (libtorrent-1_1_*|RC_1_1) ]] && boost_version="1.76.0"
        boost_github_tag="boost-${boost_version}"
        boost_url="https://archives.boost.io/release/${boost_version}/source/boost_${boost_version//./_}.tar.gz"
        boost_url_status="$(curl -so /dev/null --head --write-out '%{http_code}' "https://boostorg.jfrog.io/artifactory/main/release/${boost_version}/source/boost_${boost_version//./_}.tar.gz")"
        boost_github_url="https://github.com/boostorg/boost.git"
        #
        libtorrent_github_url="https://github.com/arvidn/libtorrent.git"
        #
        if [[ "$LIBTORRENT_USE_GITHUB_TAG" = "yes" ]]; then
                libtorrent_github_tag="$LIBTORRENT_GITHUB_TAG"
        elif [[ "$LIBTORRENT_GITHUB_TAG" = "lm_master" ]]; then
                libtorrent_github_tag="RC_${libtorrent_version//./_}"
        else
                libtorrent_github_tag=$(github_latest_version "arvidn/libtorrent")
                # libtorrent_github_tag="$(grep -Eom1 "v$libtorrent_version.([0-9]{1,2})" <(curl "https://github.com/arvidn/libtorrent/tags"))"
        fi
        #
        ltconfig_version="$(github_latest_version "ratanakvlun/deluge-ltconfig")"
        ltconfig_url="$(grep -Eom1 'ht(.*)ltConfig(.*)egg' <(curl "https://api.github.com/repos/ratanakvlun/deluge-ltconfig/releases/latest"))"
}
#####################################################################################################################################################
# This function determines which crypto is default (openssl) and what to do if wolfssl is selected.
#####################################################################################################################################################
set_libtorrent_crypto() {
        pb_libtorrent_crypto=("crypto=openssl" "openssl-lib=$install_dir/openssl-$openssl_github_tag" "openssl-include=$install_dir/openssl-$openssl_github_tag/include")
        SSL_MODULE="openssl"
        #
        if [[ "$CRYPTO_TYPE" = 'wolfssl' ]]; then
                if [[ "$LIBTORRENT_GITHUB_TAG" =~ ^(RC_2_[0-9]|v2[\.0-9]{2,3}[\.0-9]{2,2})$ ]]; then
                        pb_libtorrent_crypto=("crypto=wolfssl" "wolfssl-lib=$install_dir/wolfssl/src/.libs" "wolfssl-include=$install_dir/wolfssl")
                        SSL_MODULE="wolfssl"
                else
                        echo
                        echo -e "${cy} wolfssl only works with libtorrent v2 or above${cend}"
                        echo
                        echo -e "${td} This script defaults to the v1.2 latest version${cend}"
                        echo
                        echo -e "${cg} ~/$(basename -- "$0")${cend} ${clm}all${cend} ${clb}-c${cend} ${clm}wolfssl${cend} ${clb}-lt${cend} ${cc}RC_2_0${cend}"
                        echo
                        exit
                fi
        fi
}
#####################################################################################################################################################
# This function sets some default values we use but whose values can be overridden by certain flags
#####################################################################################################################################################
set_default_values() {
        DEBIAN_FRONTEND="noninteractive" TZ="Europe/London" # For docker deploys to not get prompted to set the timezone.
        #
        WORKING_DIR="$(printf "%s" "$(pwd <(dirname "$0"))")" # Get the full path to the scripts location to use with setting some path related variables.
        #
        MODULES=("all" "install" "${SSL_MODULE}" "boost" "libtorrent") # Define our list of available modules in an array.
        #
        SCOPE="${SCOPE:-user}" # We can define the libtorrent installation settings for the b2 command here.
        #
        if [[ "$SCOPE" = 'none' ]]; then
                LIBTORRENT_INSTALL_DIR="" # Just use stage_module to copy the libtorrent.so to the completed directory.
        else
                LIBTORRENT_INSTALL_DIR="install_module python-install-scope=${SCOPE}" # Use these commands to install the libtorrent.so.
        fi
        #
        LIBTORRENT_INSTALL_MODULE="stage_module ${LIBTORRENT_INSTALL_DIR}" # We can define the libtorrent installation settings for the b2 command here.
}
#####################################################################################################################################################
# This function determines the default version of python and what to do if version 2 is selected as this changes the name of some applications.
#####################################################################################################################################################
set_python_version() {
        PYTHON_VERSION="${PYTHON_VERSION:-3}" # Set the correct binary call for python2/python3/pip/pip3 and so on
        #
        [[ "$LIBTORRENT_GITHUB_TAG" =~ (libtorrent-1_1_*|RC_1_1) ]] && PYTHON_VERSION="${PYTHON_VERSION:-2}"
        #
        if [[ "$(source /etc/os-release && echo "$VERSION_CODENAME")" =~ (focal) && "$PYTHON_VERSION" = "2" ]]; then # We need to use python2 for focal and python for bionic
                PYTHON_VERSION="2"
                GET_PIP=""
        else
                PYTHON_VERSION="${PYTHON_VERSION/2/}"
                GET_PIP="python${PYTHON_VERSION}-pip"
        fi
}
#####################################################################################################################################################
# This function will check for a list of defined dependencies from the REQUIRED_PKGS array. Applications like python3 and python2 are dynamically set
#####################################################################################################################################################
check_dependencies() {
        REQUIRED_PKGS=("bison" "curl" "build-essential" "pkg-config" "automake" "libtool" "git" "perl" "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-dev" "python${PYTHON_VERSION/2/}-numpy" "${GET_PIP}") # Define our list of required core packages in an array.
        #
        ## Check for required dependencies
        #
        echo -e "${tn}${tb}Checking if required core dependencies are installed${cend}${tn}"
        #
        for pkg in "${REQUIRED_PKGS[@]}"; do
                if dpkg -s "$pkg" > /dev/null 2>&1; then
                        echo -e "Dependency - ${cg}OK${cend} - $pkg"
                else
                        if [[ -n "$pkg" ]]; then
                                deps_installed='no'
                                echo -e "Dependency - ${cr}NO${cend} - $pkg"
                                CHECKED_REQUIRED_PKGS+=("$pkg")
                        fi
                fi
        done
        #
        ## Check if user is able to install the dependencies, if yes then do so, if no then exit.
        #
        if [[ "$deps_installed" = 'no' ]]; then
                if [[ "$(id -un)" = 'root' ]]; then
                        #
                        echo -e "${tn}${cg}Updating${cend}${tn}"
                        #
                        set +e
                        #
                        apt-get update -y
                        apt-get upgrade -y
                        apt-get autoremove -y
                        #
                        set -e
                        #
                        [[ -f /var/run/reboot-required ]] && {
                                echo -e "${tn}${cr}This machine requires a reboot to continue installation. Please reboot now.${cend}${tn}"
                                exit
                        }
                        #
                        echo -e "${tn}${cg}Installing required dependencies${cend}${tn}"
                        #
                        apt-get install -y "${CHECKED_REQUIRED_PKGS[@]}"
                        #
                        echo -e "${tn}${cg}Dependencies installed!${cend}"
                        #
                        deps_installed='yes'
                        #
                else
                        echo -e "${tn}${tb}Please request or install the missing core dependencies before using this script${cend}"
                        #
                        echo -e "${tn}apt-get install -y ${CHECKED_REQUIRED_PKGS[*]}${tn}"
                        #
                        exit
                fi
        fi
        #
        ## All checks passed echo
        #
        if [[ "$deps_installed" = 'yes' ]]; then
                echo -e "${tn}${tb}Good, we have all the core dependencies installed, continuing to build${cend}"
        fi
}
#####################################################################################################################################################
# This function allows you to test the compiled libraries to make sure they work.
#####################################################################################################################################################
test_library_builds() {
        if [[ "$TEST_BUILD" = 'yes' ]]; then
                INSTALLED_SCOPE_SYSTEM="$(python"${PYTHON_VERSION}" -c "import distutils.sysconfig; import sys; sys.stdout.write(distutils.sysconfig.get_python_lib())")/libtorrent.so"
                INSTALLED_SCOPE_LOCAL="$(python"${PYTHON_VERSION}" -c "import site; import sys; sys.stdout.write(site.USER_SITE)")/libtorrent.so"
                INSTALLED_SCOPE_NONE="$install_dir/completed/libtorrent.so"
                #
                echo
                #
                test_library() {
                        if [[ ${1} = "${INSTALLED_SCOPE_SYSTEM}" || ${1} = "${INSTALLED_SCOPE_LOCAL}" || ${1} = "${INSTALLED_SCOPE_NONE}" ]]; then
                                echo -e "libtorrent location${cend}${td}:${cend} ${cc}${1}${cend}${tn}"
                                [[ "${1}" = "${INSTALLED_SCOPE_NONE}" ]] && cd "$install_dir/completed"
                                if python${PYTHON_VERSION} -c "import libtorrent; print(libtorrent.version)" > /dev/null 2>&1; then
                                        echo -e " ${clb}Using python${PYTHON_VERSION}${cend} - ${cy}libtorrent version${cend}${td}:${cend} ${cg}$(python${PYTHON_VERSION} -c "import libtorrent; print(libtorrent.version)")${cend}${tn}"
                                else
                                        echo -e " ${cy}libtorrent.so found but not built with python${PYTHON_VERSION}${cend}"
                                        echo
                                fi
                        fi
                }
                [[ -f "${INSTALLED_SCOPE_SYSTEM}" ]] && test_library "${INSTALLED_SCOPE_SYSTEM}"
                [[ -f "${INSTALLED_SCOPE_LOCAL}" ]] && test_library "${INSTALLED_SCOPE_LOCAL}"
                [[ -f "${INSTALLED_SCOPE_NONE}" ]] && test_library "${INSTALLED_SCOPE_NONE}"
                #
                if [[ ! -f ${INSTALLED_SCOPE_SYSTEM} && ! -f ${INSTALLED_SCOPE_LOCAL} && ! -f ${INSTALLED_SCOPE_NONE} ]]; then
                        echo -e "Sorry, but I cannot find an installed libtorrent.so library."
                        echo
                        echo -e "${cy}If you used a custom build directory please provide that via the${cend} ${clb}-b${cend} ${cy}flag${cend}"
                        echo
                fi
                exit
        fi
}
#####################################################################################################################################################
# This function verifies the module names from the array MODULES in the default values function.
#####################################################################################################################################################
installation_modules() {
        params_count="$#"
        params_test=1
        #
        while [[ "$params_test" -le "$params_count" && "$params_count" -gt '1' ]]; do
                if [[ "${MODULES[*]}" =~ ${*:$params_test:1} ]]; then
                        :
                else
                        MODULES_TEST="fail"
                fi
                params_test="$((params_test + 1))"
        done
        #
        if [[ "$params_count" -le '1' ]]; then
                if [[ "${MODULES[*]}" =~ ${*:$params_test:1} && -n "${*:$params_test:1}" ]]; then
                        :
                else
                        MODULES_TEST="fail"
                fi
        fi
        #
        # Activate all validated modules for installation and define some core variables.
        if [[ "$MODULES_TEST" != 'fail' ]]; then
                if [[ "${*}" =~ ([[:space:]]|^)"all"([[:space:]]|$) ]]; then
                        for module in "${MODULES[@]}"; do
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
                python_major="$(python${PYTHON_VERSION} -c "import sys; print(sys.version_info[0])")"
                python_minor="$(python${PYTHON_VERSION} -c "import sys; print(sys.version_info[1])")"
                python_micro="$(python${PYTHON_VERSION} -c "import sys; print(sys.version_info[2])")"
                #
                python_short_version="${python_major}.${python_minor}"
                python_link_version="${python_major}${python_minor}"
                #
                echo -e "using gcc : : : <cxxflags>-std=c++${cxxstd:-17} ;${tn}using python : ${python_short_version} : /usr/bin/python${python_short_version} : /usr/include/python${python_short_version} : /usr/lib/python${python_short_version} ;" > "$HOME/user-config.jam"
                #
                ## Echo the build directory.
                echo -e "${tn}${tb}Install Prefix${cend} : ${cg}$install_dir${cend}"
                #
                ## Some basic help
                echo -e "${tn}${tb}Script help${cend} : ${cg}~/$(basename -- "$0") -h${cend}"
        else
                echo -e "${cr}${tn}One or more of the provided modules are not supported${cend}"
                echo -e "${tb}${tn}This is a list of supported modules${cend}"
                echo -e "${clm}${tn}${MODULES[*]}${tn}${cend}"
                exit
        fi
}
#####################################################################################################################################################
# This function will test to see if a Jamfile patch file exists via the variable patches_github_url for the tag used.
#####################################################################################################################################################
apply_patches() {
        [[ -d "$install_dir/patches" ]] && rm -rf "$install_dir/patches"
        #
        [[ "$libtorrent_github_tag" =~ ^(libtorrent-1_1_[0-9]{1,2}|RC_1_1) ]] && libtorrent_patch_github_tag="RC_1_1"
        [[ "$libtorrent_github_tag" =~ ^(libtorrent-1_2_[0-9]{1,2}|RC_1_2|v1.2\.[0-9]{1,2})$ ]] && libtorrent_patch_github_tag="RC_1_2"
        [[ "$libtorrent_github_tag" =~ ^(RC_2_0|v2\.[0-9](\.[0-9]{1,2})?)$ ]] && libtorrent_patch_github_tag="RC_2_0"
        #
        patches_github_url="https://raw.githubusercontent.com/userdocs/python-libtorrent-binding/master/patches/$libtorrent_patch_github_tag/Jamfile"
        #
        if [[ "$(
                curl "$patches_github_url" > /dev/null
                echo "$?"
        )" -ne '22' ]]; then
                curl "$patches_github_url" -o "$install_dir/libtorrent/bindings/python/Jamfile"
        else
                curl "https://raw.githubusercontent.com/arvidn/libtorrent/$libtorrent_patch_github_tag/bindings/python/Jamfile" -o "$install_dir/libtorrent/bindings/python/Jamfile"
        fi
}
#####################################################################################################################################################
# This function installs deluge and lt-config locally
#####################################################################################################################################################
install_deluge() {
        if ! type "pip${PYTHON_VERSION}" > /dev/null 2>&1; then
                echo -e "No pip available for this version of python on this OS${tn}"
                exit
        fi
        #
        mkdir -p "$HOME/.config/deluge/plugins"
        curl "$ltconfig_url" -o "$HOME/.config/deluge/plugins/$ltconfig_version"
        chmod 755 "$HOME/.config/deluge/plugins/$ltconfig_version"
        #
        "pip${PYTHON_VERSION}" install --user deluge
        #
        "$HOME/.local/bin/deluged"
        "$HOME/.local/bin/deluge-console" plugin -e ltconfig
        "$HOME/.local/bin/deluge-web"
        #
        echo -e "${cg}${tn}The libtorrent python binding has been installed and started using these commands!${cend}${tn}"
        #
        echo -e "${cc}~/.local/bin/deluged${cend}${tn}"
        echo -e "${cc}~/.local/bin/deluge-console plugin -e ltconfig${cend}${tn}"
        echo -e "${cc}~/.local/bin/deluge-web${cend}${tn}"
        #
        exit
}
#####################################################################################################################################################
# This function is for downloading source code archives
#####################################################################################################################################################
download_file() {
        if [[ -n "$1" ]]; then
                url_filename="${2}"
                [[ -n "$3" ]] && subdir="/$3" || subdir=""
                echo -e "${tn}${cg}Installing $1${cend}${tn}"
                file_name="$install_dir/$1.tar.gz"
                [[ -f "$file_name" ]] && rm -rf {"${install_dir:?}/$(tar tf "$file_name" | grep -Eom1 "(.*)[^/]")","$file_name"}
                curl "${url_filename}" -o "$file_name"
                tar xf "$file_name" -C "$install_dir"
                mkdir -p "$install_dir/$(tar tf "$file_name" | head -1 | cut -f1 -d"/")${subdir}"
                cd "$install_dir/$(tar tf "$file_name" | head -1 | cut -f1 -d"/")${subdir}"
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
        if [[ -n "$1" ]]; then
                github_tag="${1}_github_tag"
                url_github="${2}"
                [[ -n "$3" ]] && subdir="/$3" || subdir=""
                echo -e "${tn}${cg}Installing $1${cend}${tn}"
                folder_name="$install_dir/$1"
                [[ -d "$folder_name" ]] && rm -rf "$folder_name"
                git ${GIT_PROXY} clone --no-tags --single-branch --branch "${!github_tag}" --shallow-submodules --recurse-submodules -j"$(nproc)" --depth 1 "${url_github}" "${folder_name}"
                mkdir -p "${folder_name}${subdir}"
                cd "${folder_name}${subdir}"
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
        if [[ -n "$1" ]]; then
                if [[ -z "$SKIP_DELETE" ]]; then
                        [[ "$2" = 'last' ]] && echo -e "${tn}${clr}Deleting $1 installation files and folders${cend}${tn}" || echo -e "${tn}${clr}Deleting $1 installation files and folders${cend}"
                        #
                        file_name="$install_dir/$1.tar.gz"
                        folder_name="$install_dir/$1"
                        [[ -f "$file_name" ]] && rm -rf {"${install_dir:?}/$(tar tf "$file_name" | grep -Eom1 "(.*)[^/]")","$file_name"}
                        [[ -d "$folder_name" ]] && rm -rf "$folder_name"
                        cd "$WORKING_DIR"
                else
                        [[ "$2" = 'last' ]] && echo -e "${tn}${clr}Skipping $1 deletion${cend}${tn}" || echo -e "${tn}${clr}Skipping $1 deletion${cend}"
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
        if [[ "$1" = 'last' ]]; then
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
                        BUILD_DIR="$2"
                        shift 2
                        ;;
                -c | --crypto)
                        if [[ ! "$2" =~ ^(openssl|wolfssl)$ ]]; then
                                echo
                                echo -e "${cy}I don't know this crypto type. Valid options are${cend} ${clm}openssl${cend} ${cy}and${cend} ${clm}wolfssl${cend}"
                                echo
                                exit
                        else
                                CRYPTO_TYPE="$2"
                        fi
                        shift 2
                        ;;
                -n | --no-delete)
                        SKIP_DELETE='yes'
                        shift
                        ;;
                -lm | --libtorrent-master)
                        LIBTORRENT_GITHUB_TAG='lm_master'
                        shift
                        ;;
                -lt | --libtorrent-tag)
                        if git ls-remote --exit-code "https://github.com/arvidn/libtorrent.git" -t "$2" > /dev/null 2>&1; then
                                LIBTORRENT_USE_GITHUB_TAG="yes"
                                LIBTORRENT_GITHUB_TAG="$2"
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
                        GIT_PROXY="-c http.sslVerify=false -c http.https://github.com.proxy=$2"
                        CURL_PROXY="-x $2"
                        shift 2
                        ;;
                -pv | --python-version)
                        if [[ ! "$2" =~ ^(2|3)$ ]]; then
                                echo
                                echo -e "${cy}I don't know this python version. Valid options are${cend} ${cc}2${cend} ${cy}or${cend} ${cc}3${cend}"
                                echo
                                exit
                        else
                                PYTHON_VERSION="$2"
                                shift 2
                        fi
                        ;;
                -tb | --test-build)
                        TEST_BUILD='yes'
                        shift
                        ;;
                -s | --scope)
                        SCOPE="${2:-user}"
                        if [[ ! "$SCOPE" =~ ^(none|user|system)$ ]]; then
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
                        echo
                        echo -e "${tb}${tu}Here are a list of available options${cend}"
                        echo
                        echo -e " ${cg}Use:${cend} ${clb}-b${cend}  ${td}or${cend} ${clb}--build-directory${cend}   ${cy}Help:${cend} ${clb}-h-b${cend}  ${td}or${cend} ${clb}--help-build-directory${cend}"
                        echo -e " ${cg}Use:${cend} ${clb}-c${cend}  ${td}or${cend} ${clb}--crypto${cend}            ${cy}Help:${cend} ${clb}-h-c${cend}  ${td}or${cend} ${clb}--help-crypto${cend}"
                        echo -e " ${cg}Use:${cend} ${clb}-n${cend}  ${td}or${cend} ${clb}--no-delete${cend}         ${cy}Help:${cend} ${clb}-h-n${cend}  ${td}or${cend} ${clb}--help-no-delete${cend}"
                        echo -e " ${cg}Use:${cend} ${clb}-lm${cend} ${td}or${cend} ${clb}--libtorrent-master${cend} ${cy}Help:${cend} ${clb}-h-lm${cend} ${td}or${cend} ${clb}--help-libtorrent-master${cend}"
                        echo -e " ${cg}Use:${cend} ${clb}-lt${cend} ${td}or${cend} ${clb}--libtorrent-tag${cend}    ${cy}Help:${cend} ${clb}-h-lt${cend} ${td}or${cend} ${clb}--help-libtorrent-tag${cend}"
                        echo -e " ${cg}Use:${cend} ${clb}-p${cend}  ${td}or${cend} ${clb}--proxy${cend}             ${cy}Help:${cend} ${clb}-h-p${cend}  ${td}or${cend} ${clb}--help-proxy${cend}"
                        echo -e " ${cg}Use:${cend} ${clb}-pv${cend} ${td}or${cend} ${clb}--python-version${cend}    ${cy}Help:${cend} ${clb}-h-pv${cend} ${td}or${cend} ${clb}--help-python-version${cend}"
                        echo -e " ${cg}Use:${cend} ${clb}-tb${cend} ${td}or${cend} ${clb}--test-build${cend}        ${cy}Help:${cend} ${clb}-h-tb${cend} ${td}or${cend} ${clb}--help-test-build${cend}"
                        echo -e " ${cg}Use:${cend} ${clb}-s${cend}  ${td}or${cend} ${clb}--scope${cend}             ${cy}Help:${cend} ${clb}-h-s${cend}  ${td}or${cend} ${clb}--help-scope${cend}"
                        echo
                        echo -e "${tb}${tu}Module specific help - flags are used with the modules listed here.${cend}"
                        echo
                        echo -e "${cg}Use:${cend} ${clm}all${cend} ${td}or${cend} ${clm}module-name${cend}         ${cy}Usage:${cend} ${cg}~/$(basename -- "$0")${cend} ${clm}all${cend}"
                        echo
                        echo -e " ${clm}all${cend}         ${td}-${cend} ${td}Install all modules - openssl boost libtorrent${cend}"
                        echo -e " ${clm}openssl${cend}     ${td}-${cend} ${td}Install the openssl module${cend} ${cy}(default)${cend}"
                        echo -e " ${clm}wolfssl${cend}     ${td}-${cend} ${td}Install the wolf module${cend} ${cy}(Libtorrent v2 only)${cend}"
                        echo -e " ${clm}boost${cend}       ${td}-${cend} ${td}Download, extract and bootstrap the boost build files${cend}"
                        echo -e " ${clm}libtorrent${cend}  ${td}-${cend} ${td}Build the libtorrent python binding${cend}"
                        echo
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
                        echo -e " ${td}Example:${cend} ${cg}~/$(basename -- "$0")${cend} ${clm}all${cend} ${td}- Will install all modules and build libtorrent to the default build location"${cend}
                        echo
                        echo -e " ${td}Example:${cend} ${cg}~/$(basename -- "$0")${cend} ${clm}all ${clb}-b${cend} \"\$HOME/build\"${cend} ${td}- Will specify a build directory and install all modules to that custom location${cend}"
                        echo
                        echo -e " ${td}Example:${cend} ${cg}~/$(basename -- "$0")${cend} ${clm}module${cend} ${td}- Will install a single module to the default build location${cend}"
                        echo
                        echo -e " ${td}Example:${cend} ${cg}~/$(basename -- "$0")${cend} ${clm}module${cend} ${clb}-b${cend} \"\$HOME/build\"${cend} ${td}- will specify a custom build directory and install a specific module use to that custom location${cend}"
                        #
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
                        echo -e " ${cg}~/$(basename -- "$0")${cend}${clb} -lt ${clc}12345${cend} ${clb}-h-lt${cend}"
                        [[ -n "$LIBTORRENT_GITHUB_TAG" ]] && echo -e "${tn} This tag that will be used is: ${cg}$LIBTORRENT_GITHUB_TAG${cend}"
                        echo
                        echo -e " ${td}This flag must be provided with arguments.${cend}"
                        echo
                        echo -e " ${clb}-lt${cend} ${clc}libtorrent-1_1_14${cend}"
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
                        echo -e " ${cg}~/$(basename -- "$0")${cend} ${clb}-p${cend} ${clc}https://proxy.com:12345${cend} ${clb}-h-p${cend}"
                        echo
                        [[ -n "$GIT_PROXY" ]] && echo -e " git proxy command: $GIT_PROXY"
                        [[ -n "$CURL_PROXY" ]] && echo -e " curl proxy command: $CURL_PROXY${tn}"
                        exit 1
                        ;;
                -h-pv | --help-python-version)
                        echo
                        echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
                        echo
                        echo -e " Default Python version: ${cg}python3${cend}"
                        echo
                        echo -e " You can choose ${clc}2${cend} or ${clc}3${cend} - The script defaults to version ${clc}3${cend}"
                        echo
                        echo -e " ${td}This flag must be provided with arguments.${cend}"
                        echo
                        echo -e " ${clb}-pv${cend} ${clc}2${cend}"
                        echo
                        exit 1
                        ;;
                -h-tb | --help-test-build)
                        echo
                        echo -e "${tb}${tu}Here is the help description for this flag:${cend}"
                        echo
                        echo -e "Use this to test the compiled python binding."
                        echo
                        echo -e "${cy}If you built against python2 you need to also use the ${clb}-pv${cend} 2 ${cy}flag${cend}"
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
set_build_directory # see functions
#
set_module_urls # see functions
#
set_libtorrent_crypto # see functions
#
set_default_values # see functions
#
set_python_version # see functions
#
check_dependencies # see functions
#
test_library_builds # see functions
#
installation_modules "$@" # see functions
#
[[ "${*}" =~ ([[:space:]]|^)"install"([[:space:]]|$) ]] && install_deluge # see functions
#####################################################################################################################################################
# openssl installation
#####################################################################################################################################################
application_name openssl
#
if [[ "${!app_name_skip:-yes}" = 'no' || "$1" = "$app_name" ]]; then
        custom_flags_set
        download_file "$app_name" "${!app_url}"
        #
        ./config --prefix="$install_dir" threads no-shared no-dso no-comp CXXFLAGS="$CXXFLAGS" CPPFLAGS="$CPPFLAGS" LDFLAGS="$LDFLAGS" 2>&1 | tee "$install_dir/logs/$app_name.log.txt"
        make -j"$(nproc)" 2>&1 | tee -a "$install_dir/logs/$app_name.log.txt"
else
        application_skip
fi
#####################################################################################################################################################
# wolf installation
#####################################################################################################################################################
application_name wolfssl
#
if [[ "${!app_name_skip:-yes}" = 'no' || "$1" = "$app_name" ]]; then
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
#
if [[ "${!app_name_skip:-yes}" = 'no' ]] || [[ "$1" = "$app_name" ]]; then
        custom_flags_set
        #
        [[ -d "$install_dir/boost" ]] && delete_function "$app_name"
        #
        if [[ "$boost_url_status" -eq '200' ]]; then
                download_file "$app_name" "$boost_url"
                mv -f "$install_dir/boost_${boost_version//./_}/" "$install_dir/boost"
                cd "$install_dir/boost"
        fi
        #
        if [[ "$boost_url_status" -eq '403' ]]; then
                download_folder "$app_name" "${!app_github_url}"
        fi
        #
        "$install_dir/boost/bootstrap.sh" 2>&1 | tee "$install_dir/logs/$app_name.log.txt"
        "$install_dir/boost/b2" headers
else
        application_skip
fi
#####################################################################################################################################################
# libtorrent install
#####################################################################################################################################################
application_name libtorrent
#
if [[ "${!app_name_skip:-yes}" = 'no' ]] || [[ "$1" = "$app_name" ]]; then
        if [[ ! -d "$install_dir/boost" ]]; then
                echo -e "${tn}${clr}Warning${cend} - You must install the boost module before you can use the libtorrent module"
        else
                custom_flags_set
                download_folder "$app_name" "${!app_github_url}"
                #
                BOOST_ROOT="$install_dir/boost"
                BOOST_INCLUDEDIR="$install_dir/boost"
                BOOST_BUILD_PATH="$install_dir/boost"
                #
                apply_patches # see functions
                #
                cd "$folder_name/bindings/python"
                #
                "$install_dir/boost/b2" -j"$(nproc)" "${pb_libtorrent_crypto[@]}" address-model="$(getconf LONG_BIT)" cxxstd="${cxxstd:-17}" fpic=on dht=on encryption=on i2p=on extensions=on variant=release threading=multi libtorrent-link=static boost-link=static cxxflags="$CXXFLAGS" cflags="$CPPFLAGS" linkflags="$LDFLAGS -lgcov --coverage" ${LIBTORRENT_INSTALL_MODULE} 2>&1 | tee "$install_dir/logs/libtorrent.log.txt"
                #
                [[ -f "$install_dir/libtorrent/bindings/python/libtorrent.so" ]] && cp "$install_dir/libtorrent/bindings/python/libtorrent.so" "$install_dir/completed/libtorrent.so"
                #
                delete_function "$SSL_MODULE"
                delete_function boost
                delete_function "$app_name" last
        fi
else
        application_skip last
fi
#####################################################################################################################################################
# We are all done so now exit
#####################################################################################################################################################
exit

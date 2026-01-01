#!/bin/sh
set -e
# Git for Linux installation script.
#
# This script is intended as a convenient way to configure package
# repositories and to install Git.
#
# The script:
#
# - Requires `root` or `sudo` privileges to run.
# - Attempts to detect your Linux distribution and version and configure your
#   package management system for you.
# - Installs dependencies and recommendations without asking for confirmation.
# - Installs the latest stable release (by default) of Git.
#
# Usage
# ==============================================================================
#
# To install the latest stable versions of Git and dependencies:
#
# 1. download the script
#
#   $ curl -fsSL https://raw.githubusercontent.com/ElliottStorey/git-install/main/install.sh -o install-git.sh
#
# 2. run the script with --dry-run to verify the steps it executes
#
#   $ sh install-git.sh --dry-run
#
# 3. run the script either as root, or using sudo to perform the installation.
#
#   $ sudo sh install-git.sh
#
# Command-line options
# ==============================================================================
#
# --version <VERSION>
# Use the --version option to install a specific version (Best effort), for example:
#
#   $ sudo sh install-git.sh --version 2.40.0
#
# ==============================================================================

# Script versioning
SCRIPT_COMMIT_SHA="git-script-v1.0.0"

# strip "v" prefix if present
VERSION="${VERSION#v}"

DRY_RUN=${DRY_RUN:-}
REPO_ONLY=${REPO_ONLY:-0}

while [ $# -gt 0 ]; do
	case "$1" in
		--dry-run)
			DRY_RUN=1
			;;
		--version)
			VERSION="${2#v}"
			shift
			;;
		--setup-repo)
			REPO_ONLY=1
			shift
			;;
		--*)
			echo "Illegal option $1"
			;;
	esac
	shift $(( $# > 0 ? 1 : 0 ))
done

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

is_dry_run() {
	if [ -z "$DRY_RUN" ]; then
		return 1
	else
		return 0
	fi
}

is_darwin() {
	case "$(uname -s)" in
	*darwin* ) true ;;
	*Darwin* ) true ;;
	* ) false;;
	esac
}

deprecation_notice() {
	distro=$1
	distro_version=$2
	echo
	printf "\033[91;1mDEPRECATION WARNING\033[0m\n"
	printf "    This Linux distribution (\033[1m%s %s\033[0m) reached end-of-life and is no longer supported by this script.\n" "$distro" "$distro_version"
	echo   "    No updates or security fixes will be released for this distribution."
	echo
	printf   "Press \033[1mCtrl+C\033[0m now to abort this script, or wait for the installation to continue."
	echo
	sleep 10
}

get_distribution() {
	lsb_dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	echo "$lsb_dist"
}

echo_git_success() {
	if is_dry_run; then
		return
	fi
	
    echo
	echo "================================================================================"
	echo
    echo "Git has been installed successfully."
    echo
    if command_exists git; then
        (
            set -x
            git --version
        ) || true
    fi
    echo
    echo "To configure your global identity, run:"
    echo "  git config --global user.name \"Your Name\""
    echo "  git config --global user.email \"you@example.com\""
	echo
	echo "================================================================================"
	echo
}

# Check if this is a forked Linux distro
check_forked() {
	if command_exists lsb_release; then
		set +e
		lsb_release -a -u > /dev/null 2>&1
		lsb_release_exit_code=$?
		set -e

		if [ "$lsb_release_exit_code" = "0" ]; then
			lsb_dist=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'id' | cut -d ':' -f 2 | tr -d '[:space:]')
			dist_version=$(lsb_release -a -u 2>&1 | tr '[:upper:]' '[:lower:]' | grep -E 'codename' | cut -d ':' -f 2 | tr -d '[:space:]')
		else
			if [ -r /etc/debian_version ] && [ "$lsb_dist" != "ubuntu" ] && [ "$lsb_dist" != "raspbian" ]; then
				lsb_dist=debian
				dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
				case "$dist_version" in
					12) dist_version="bookworm" ;;
					11) dist_version="bullseye" ;;
					10) dist_version="buster" ;;
				esac
			fi
		fi
	fi
}

do_install() {
	echo "# Executing git install script, commit: $SCRIPT_COMMIT_SHA"

	if command_exists git; then
		cat >&2 <<-'EOF'
			Warning: "git" command appears to already exist on this system.

			If you installed the current Git package using this script and are using it
			again to update Git, you can ignore this message.

			You may press Ctrl+C now to abort this script.
		EOF
		( set -x; sleep 5 )
	fi

	user="$(id -un 2>/dev/null || true)"

	sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo; then
			sh_c='sudo -E sh -c'
		elif command_exists su; then
			sh_c='su -c'
		else
			cat >&2 <<-'EOF'
			Error: this installer needs the ability to run commands as root.
			We are unable to find either "sudo" or "su" available to make this happen.
			EOF
			exit 1
		fi
	fi

	if is_dry_run; then
		sh_c="echo"
	fi

	# perform some very rudimentary platform detection
	lsb_dist=$( get_distribution )
	lsb_dist="$(echo "$lsb_dist" | tr '[:upper:]' '[:lower:]')"

	case "$lsb_dist" in
		ubuntu)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --codename | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/lsb-release ]; then
				dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
			fi
		;;

		debian|raspbian)
			dist_version="$(sed 's/\/.*//' /etc/debian_version | sed 's/\..*//')"
			case "$dist_version" in
				12) dist_version="bookworm" ;;
				11) dist_version="bullseye" ;;
				10) dist_version="buster" ;;
			esac
		;;

		centos|rhel)
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;

		*)
			if command_exists lsb_release; then
				dist_version="$(lsb_release --release | cut -f2)"
			fi
			if [ -z "$dist_version" ] && [ -r /etc/os-release ]; then
				dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
			fi
		;;

	esac

	# Check if this is a forked Linux distro
	check_forked

	# Print deprecation warnings for distro versions that recently reached EOL
	case "$lsb_dist.$dist_version" in
		centos.7|rhel.7)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		debian.buster|debian.stretch)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
		ubuntu.xenial|ubuntu.trusty)
			deprecation_notice "$lsb_dist" "$dist_version"
			;;
	esac

	# Run setup for each distro accordingly
	case "$lsb_dist" in
		ubuntu)
			# On Ubuntu, we use the git-core PPA to get the latest stable version
			# similar to how Docker uses its own repo.
			pre_reqs="software-properties-common"
			(
				if ! is_dry_run; then
					set -x
				fi
				$sh_c 'apt-get -qq update >/dev/null'
				$sh_c "DEBIAN_FRONTEND=noninteractive apt-get -y -qq install $pre_reqs >/dev/null"
				$sh_c "add-apt-repository -y ppa:git-core/ppa"
				$sh_c 'apt-get -qq update >/dev/null'
			)

			if [ "$REPO_ONLY" = "1" ]; then
				exit 0
			fi

			(
				pkgs="git"
				if ! is_dry_run; then
					set -x
				fi
				$sh_c "DEBIAN_FRONTEND=noninteractive apt-get -y -qq install $pkgs >/dev/null"
			)
			echo_git_success
			exit 0
			;;
		debian|raspbian)
			# On Debian, we stick to standard repos or backports if configured, 
            # to avoid PPA complexity.
			(
				if ! is_dry_run; then
					set -x
				fi
				$sh_c 'apt-get -qq update >/dev/null'
			)

			if [ "$REPO_ONLY" = "1" ]; then
				exit 0
			fi

			(
				pkgs="git"
				if ! is_dry_run; then
					set -x
				fi
				$sh_c "DEBIAN_FRONTEND=noninteractive apt-get -y -qq install $pkgs >/dev/null"
			)
			echo_git_success
			exit 0
			;;
		centos|fedora|rhel)
			(
				if ! is_dry_run; then
					set -x
				fi
				# Ensure basic utils
				if command_exists dnf; then
					$sh_c "dnf makecache"
				else
					$sh_c "yum makecache"
				fi
			)

			if [ "$REPO_ONLY" = "1" ]; then
				exit 0
			fi

			if command_exists dnf; then
				pkg_manager="dnf"
				pkg_manager_flags="-y -q"
			else
				pkg_manager="yum"
				pkg_manager_flags="-y -q"
			fi
			
			(
				pkgs="git"
				if ! is_dry_run; then
					set -x
				fi
				$sh_c "$pkg_manager $pkg_manager_flags install $pkgs"
			)
			echo_git_success
			exit 0
			;;
		*)
			if [ -z "$lsb_dist" ]; then
				if is_darwin; then
					echo
					echo "ERROR: Unsupported operating system 'macOS'"
					echo "Please use Homebrew (brew install git) or the XCode command line tools."
					echo
					exit 1
				fi
			fi
			echo
			echo "ERROR: Unsupported distribution '$lsb_dist'"
			echo
			exit 1
			;;
	esac
	exit 1
}

# wrapped up in a function so that we have some protection against only getting
# half the file during "curl | sh"
do_install

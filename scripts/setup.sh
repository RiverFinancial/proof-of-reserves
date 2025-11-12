set -euo pipefail

# This script is used to setup the project, install erlang, elixir, and mix dependencies.
# NOTE: it currently assumes you are using MacOS or a Linux distribution derived from Debian or RedHat

# Install dependencies for mise (curl, git, etc.)
function install_mise_deps() {
	case $(uname -s) in
	# MacOS
	Darwin*)
		echo "Setting up project for MacOS"
		brew install coreutils curl git openssl
		;;
	# Linux
	Linux*)
		echo "Setting up project for Linux"

		required_packages="curl git automake autoconf libncurses-dev unzip gcc build-essential autoconf m4 libncurses-dev libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils openjdk-17-jdk"

		# Currently supporting APT, APK, and DNF only.
		for candidate in apt-get dnf 
		do
			if [ -x "$(command -v ${candidate})" ]
			then
				package_manager=$candidate
			fi
		done

		if [ -z "${package_manager+X}" ]
		then
			>&2 echo "Unknown package manager."
			exit +1
		fi

		# Not all systems will have sudo
		"${package_manager}" install -y $required_packages
		;;
	*)
		>&2 echo "Unsupported OS: $(uname -s)"
		exit +2
		;;
	esac
}

function install_mise() {
	echo "Installing mise (version manager for erlang and elixir)..."
	
	# Check if mise is already installed
	if command -v mise &> /dev/null; then
		echo "mise is already installed, skipping installation..."
		return
	fi

	# Install mise using the official installer
	curl https://mise.run | sh

	# Add mise to PATH for the current session
	export PATH="$HOME/.local/bin:$PATH"

	# Add mise to shell configuration
	if [ -z "${SHELL+X}" ]; then
		SHELL=$(echo $0)
	fi

	case $SHELL in
		*/bash)
			if ! grep -q 'eval "$(~/.local/bin/mise activate bash)"' ~/.bashrc 2>/dev/null; then
				echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc
			fi
			eval "$(~/.local/bin/mise activate bash)"
			echo "Sourcing mise for bash"
			;;
		*/zsh)
			if ! grep -q 'eval "$(~/.local/bin/mise activate zsh)"' ~/.zshrc 2>/dev/null; then
				echo 'eval "$(~/.local/bin/mise activate zsh)"' >> ~/.zshrc
			fi
			eval "$(~/.local/bin/mise activate zsh)"
			echo "Sourcing mise for zsh"
			;;
		*/fish)
			if ! grep -q '~/.local/bin/mise activate fish' ~/.config/fish/config.fish 2>/dev/null; then
				echo '~/.local/bin/mise activate fish | source' >> ~/.config/fish/config.fish
			fi
			~/.local/bin/mise activate fish | source
			echo "Sourcing mise for fish"
			;;
		*)
			>&2 echo "Unsupported shell: $SHELL"
			>&2 echo "Please add mise to your PATH and run: mise activate"
			exit +3
			;;
	esac
}

function install_erlang_elixir() {
	echo "Installing erlang and elixir..."
	# Install erlang & elixir using mise.
	# The versions will be installed according to the mise.toml file.
	
	# Ensure mise is in PATH
	export PATH="$HOME/.local/bin:$PATH"
	
	MISE=$(which mise || echo "$HOME/.local/bin/mise")
	
	if [ ! -x "$MISE" ]; then
		echo "mise not found, please install mise first"
		exit +4
	fi

	echo "Installing tools with mise: $MISE"
	$MISE install
}

function install_mix_deps() {
	echo "Installing and compiling elixir dependencies..."
	# Fetch and compile the Elixir project dependencies. 
	# Exclude dev and test dependencies to speed up the process.
	MIX_ENV=prod mix deps.get && mix deps.compile
}

function compile_project() {
	echo "Compiling elixir tool..."
	# Compile the Elixir project.
	MIX_ENV=prod mix compile
}

# This function is the main entry point for the setup script.
# It installs the dependencies, sets up the project, and compiles the project.
function setup_project() {
	echo "Installing dependencies (elixir, erlang, etc.)..."
	# Install dependencies for mise and Elixir. 
	# Openssl is required for elixir's crypto library.
	install_mise_deps
	if ! command -v elixir &> /dev/null; then 
		echo "Elixir is not installed, searching for mise to install elixir..."
		export PATH="$HOME/.local/bin:$PATH"
		if ! command -v mise &> /dev/null; then 
			echo "mise not found, installing mise..."
			install_mise
		else
			echo "mise found, installing elixir..."
		fi
		install_erlang_elixir
	else
		echo "Elixir found, skipping installation..."
	fi

	install_mix_deps
	compile_project

	echo "Setup complete! You are ready to run the verification script."
}

setup_project

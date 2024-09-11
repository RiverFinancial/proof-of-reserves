set -euo pipefail

# This script is used to setup the project, install erlang, elixir, and mix dependencies.
# NOTE: it currently assumes you are using MacOS or a Linux distribution derived from Debian or RedHat

# Install dependencies for asdf (curl, git, etc.)
function install_asdf_deps() {
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

function install_asdf() {
	echo "Installing asdf (version manager for erlang and elixir)..."
	ASDF_DIR="$HOME/.asdf"

	# Avoid reinstalling if asdf directory exists.
	if [ -d "$ASDF_DIR" ]
	then
		echo "Existing asdf directory found, skipping installation..."
		return
	fi

	git clone https://github.com/asdf-vm/asdf.git "$ASDF_DIR"

	ASDF_ENV="$ASDF_DIR/asdf.sh"

	# Add asdf to your shell and source RC file to include ASDF path additions.
	if [ -z "${SHELL+X}" ]; then
		SHELL=$(echo $0)
	fi

	case $SHELL in
		*/bash)
			echo "\nsource $ASDF_ENV" >> ~/.bashrc
			source "$ASDF_ENV"

			echo "Sourcing asdf $ASDF_ENV"
			;;
		*/zsh)
			echo "\nsource $ASDF_ENV" >> ~/.zshrc
			source "$ASDF_ENV"

			echo "Sourcing asdf $ASDF_ENV"
			;;
		*/fish)
			echo "\nsource $HOME/.asdf/asdf.fish" >> ~/.config/fish/config.fish
			# TODO: Reload to adjust path?

			echo "Sourcing asdf $ASDF_ENV"
			;;
		*)
			>&2 echo "Unsupported shell: $SHELL"
			>&2 echo "Please add the following line to your shell configuration file:"
			>&2 echo ". $HOME/.asdf/asdf.sh"
			exit +3
			;;
	esac
}

function install_erlang_elixir() {
	echo "Installing erlang and elixir..."
	# Install erlang & elixir using asdf.
	# The plugins will be added to asdf and the versions will be installed according to the .tool-versions file.
	ASDF=$(which asdf)
	if [ -f "$HOME/.asdf/asdf.sh" ]; then
		echo "Sourcing asdf"
		source "$HOME/.asdf/asdf.sh"
	fi

	if [ -z "${ASDF+X}" ]; then
		echo "asdf not found, please install asdf first"
		exit +4
	fi

	echo "Adding asdf plugins: $ASDF"
	$ASDF plugin add erlang || true
	$ASDF plugin add elixir || true
	$ASDF install
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
	# Install dependencies for asdf and Elixir. 
	# Openssl is required for elixir's crypto library.
	install_asdf_deps
	if ! command -v elixir &> /dev/null; then 
		echo "Elixir is not installed, searching for asdf to install elixir..."
		if ! command -v asdf &> /dev/null; then 
			echo "asdf not found, installing dependencies for asdf..."
			install_asdf
		else
			echo "asdf found, installing elixir..."
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

#!/bin/bash
set -euo pipefail

# This script is used to setup the project, install erlang, elixir, and mix dependencies.
# NOTE: it currently assumes you are using MacOS or a Linux distribution derived from Debian or RedHat

# Install dependencies for asdf (curl, git, etc.)
function install_asdf_deps() {
	case $(uname -s) in
	# MacOS
	Darwin*)
		echo "Setting up project for MacOS"
		brew install coreutils curl git
		;;
	# Linux
	Linux*)
		echo "Setting up project for Linux"

		# Currently supporting APT & DNF only.
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

		sudo "${package_manager}" install -y curl git automake autoconf libncurses-dev
		;;
	*)
		>&2 echo "Unsupported OS: $(uname -s)"
		exit +2
		;;
	esac
}

function install_asdf() {
	ASDF_DIR="$HOME/.asdf"

	# Avoid reinstalling if ASDF directory exists.
	if [ -d "$ASDF_DIR" ]
	then
		echo "Existing ASDF directory found, skipping installation..."
		return
	fi

	git clone https://github.com/asdf-vm/asdf.git "$ASDF_DIR"

	ASDF_ENV="$ASDF_DIR/asdf.sh"

	# Add asdf to your shell and source RC file to include ASDF path additions.
	case $SHELL in
		*/bash)
			echo -e "\nsource $ASDF_ENV" >> ~/.bashrc
			source "$ASDF_ENV"
			;;
		*/zsh)
			echo -e "\nsource $ASDF_ENV" >> ~/.zshrc
			source "$ASDF_ENV"
			;;
		*/fish)
			echo -e "\nsource $HOME/.asdf/asdf.fish" >> ~/.config/fish/config.fish
			# TODO: Reload to adjust path?
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
	# Install erlang & elixir using asdf.
	# The plugins will be added to asdf and the versions will be installed according to the .tool-versions file.
	asdf plugin add erlang
	asdf plugin add elixir
	asdf install
}

function install_mix_deps() {
	# Fetch and compile the Elixir project dependencies.
	mix deps.get && mix deps.compile
}

function compile_project() {
	# Compile the Elixir project.
	mix compile
}

# This function is the main entry point for the setup script.
# It installs the dependencies, sets up the project, and compiles the project.
function setup_project() {
	install_asdf_deps
	install_asdf
	install_erlang_elixir
	install_mix_deps
	compile_project
}

setup_project

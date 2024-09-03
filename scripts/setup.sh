#!/bin/sh

# This script is used to setup the project, install erlang, elixir, and mix dependencies.
# NOTE: it currently assumes you are using MacOS.

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
		sudo apt install curl git -y
		# TODO: what if they don't use apt or don't have sudo?
		;;
	*)
		echo "Unsupported OS: $(uname -s)"
		exit 1
		;;
	esac
}

function install_asdf() {
	git clone https://github.com/asdf-vm/asdf.git ~/.asdf

	# Add asdf to your shell
	case $SHELL in
		*/bash)
			echo -e "\n. $HOME/.asdf/asdf.sh" >> ~/.bashrc
			;;
		*/zsh)
			echo -e "\n. $HOME/.asdf/asdf.sh" >> ~/.zshrc
			;;
		*/fish)
			echo -e "\nsource $HOME/.asdf/asdf.fish" >> ~/.config/fish/config.fish
			;;
		*)
			echo "Unsupported shell: $SHELL"
			echo "Please add the following line to your shell configuration file:"
			echo ". $HOME/.asdf/asdf.sh"
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

#!bin/bash

#get the root access first and check the OS type
OS_type=$(uname -s)
while true; do
    read -p "Are you a sudoer? [y/N]: " yn
    case $yn in
        [Yy]* ) is_sudoer=1; break;;
        [Nn]* ) is_sudoer=0; break;;
        "") is_sudoer=0; break;;
        * ) ;;
    esac
done

#---------------------------------------------#
# install some system things

# install some packages, credit to: https://github.com/Alfons0329/myconfig/blob/master/install.sh
if [ $is_sudoer -eq 1 ]; then
	if [ "OS_type" = "Linux" ]; then
    	echo $(OS_type)
	    sudo apt-get update
	    for i in zsh mosh vim tmux node install git wget python-dev python-pip python3-dev python3-pip nodejs xsel cmake; do
	        sudo apt-get --yes --force-yes -f -m install $i
	    done
	    # fix 'no such file: /usr/local/bin/node' issue
	    sudo ln -s /usr/bin/nodejs /usr/local/bin/node
	elif [ "$(OS_type)" = "Darwin" ]; then # mac
	    echo $(OS_type)
	    # check if brew exists. If not, install it
	    hash brew 2>/dev/null || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
	    brew install wget zsh mosh tmux reattach-to-user-namespace
	    brew install git python3 node gnu-sed cmake
        brew install thefuck cmake
        brew install vim && brew install macvim
        brew link macvim
        easy_install pip pip3
        brew install git
        npm install -g bower
	else
	    echo $(OS_type)
	    echo "This OS is not supported yet!"
	    exit 0
	fi
fi

#---------------------------------------------#
#vim relate

#install awesome vimrc
git clone --depth=1 https://github.com/amix/vimrc.git ~/.vim_runtime
sh ~/.vim_runtime/install_awesome_vimrc.sh

#install youcomplete me
cd ~
git clone https://github.com/Valloric/YouCompleteMe.git
cd YouCompleteMe/ && python install.py

#youcompelete me need these submobules, otherwise not able to run
cd ~/.vim/bundle/YouCompleteMe
git submodule update --init --recursive

#and finally build and run
python3 ~/.vim/bundle/YouCompleteMe/install.py


#---------------------------------------------#
#install the library for CTF

pip inatall pycrypto
pip3 install pycrypto




#!bin/bash

#get the root access first
sudo -s

#---------------------------------------------#
#install some system things
easy_install pip pip3
brew install git


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


#install




# Unix_Configuration
* My unix configuration for install unix-like system.
* Actually, I am using# dotfiles

* My UNIX-Like post OS installation scripts.

| OS    | Support | Notes |
| ------ | ------- | ----- |
| macOS  | Yes     |       |
| Ubuntu | Yes     |       |
|        |         |       |
|        |         |       |
|        |         |       |
|        |         |       |
|        |         |       |

## The `install.sh` will install the following packages and dependencies ()
* Original install.sh credit to [toosyou](), and I forked from his for my own purpose.

- [brew](https://brew.sh/) (macos only)
- zsh  
    - [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)  
    - [bullet-train.zsh](https://github.com/caiogondim/bullet-train.zsh)  
      - Which needs powerline compatible fonts like [Vim Powerline patched fonts](https://github.com/Lokaltog/powerline-fonts), [Input Mono](http://input.fontbureau.com/) or [Monoid](http://larsenwork.com/monoid/).  
    - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)  
    - [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)  
    - some **aliases** with commands that I always type wrong.  
- [mosh](https://mosh.org/)
- [thefuck](https://github.com/nvbn/thefuck)
- vim  
    - [Vundle](https://github.com/VundleVim/Vundle.vim)  
    - [The ultimate Vim configuration: vimrc](https://github.com/amix/vimrc)  
    - [delimitMate](https://github.com/Raimondi/delimitMate)  
    - [YouCompleteMe](https://github.com/Valloric/YouCompleteMe)(with C-family languages support)
- tmux  
    - mouse support  
    - [Tmux Plugin Manager](https://github.com/tmux-plugins/tpm) (tmux >= 2.3)  
    - [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) (tmux >= 2.3)  
    - [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) (tmux >= 2.3)  
    - [tmux-yank](https://github.com/tmux-plugins/tmux-yank) (tmux >= 2.3)  
    - [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum)(tmux >= 2.3)  
- git
- wget
- python3
- pip3

## Install my own vimrcs and tmux configuraion
* This will overwrite all your vimrc and tmux configurations!
* Just do `bash install_rc.sh` macOS now partly because of the Apple eco system.

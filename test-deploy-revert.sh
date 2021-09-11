#!/bin/bash

# test deploy from current dir, to test the thing.

set -e

if [[ ! -d $HOME/.vim-bak ]]; then

    echo "can't revert test deploy, directory $HOME/.vim-bak does not exist"
    exit 1
fi

if [[ ! -f $HOME/.vimrc-bak ]]; then

    echo "can't revert test deploy, file $HOME/.vimrc-bak already exists"
    exit 1
fi

rm -f $HOME/.vimrc
rm -rf $HOME/.vim 

if [[ ! -d  $HOME/.vim/pack/vendor/start/gitblame ]]; then
    rm -f $HOME/.vim/pack/vendor/start/gitblame
fi

mv $HOME/.vim-bak $HOME/.vim
mv $HOME/.vimrc-bak $HOME/.vimrc





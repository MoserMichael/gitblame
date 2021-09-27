#!/bin/bash

echo "create zip"

set -e

echo "*** test deploy from current dir, to test the thing. ***"
./bundle.sh

if [[ -d $HOME/.vim-bak ]]; then

    echo "can't test deploy, directory $HOME/.vim-bak already exists"
    exit 1
fi

if [[ -f $HOME/.vimrc-bak ]]; then

    echo "can't test deploy, file $HOME/.vimrc-bak already exists"
    exit 1
fi


mv $HOME/.vim $HOME/.vim-bak
mv $HOME/.vimrc $HOME/.vimrc-bak


mkdir -p ~/.vim/pack/vendor/start/gitblame; unzip gitblame.zip -d  ~/.vim/pack/vendor/start/gitblame





#!/bin/bash

set -ex

if [[ -f gitblame.zip ]]; then
  rm -f giblame.zip 
fi

zip gitblame.zip $(git ls-files | grep -v $0)

# The gitblame vim plugin

This project is a minimal vim plugin for working with git; it first did ```git blame```, later added support for ```git grep```, ```git log --graph```, ```git ls-files```, ```git diff```, ```git log --name-status --find-renames```, ```git status``` commands, it also allows you to change the current branch and shows the current branch in the status line (optionally).
It's not too overengineered, so there is a chance that it will work for your installation too.

For more information, see [help text](https://github.com/MoserMichael/gitblame/blob/master/doc/gitblame.txt)

This plugin is currently not supporting merges/rebases, as I am used to doing these from the command line. You have got a different plugin, [vim fugitive](https://github.com/tpope/vim-fugitive), if you need to do merge/rebase from vim.

This plugin is part of my [work environment](https://github.com/MoserMichael/myenv), this project publishes it separately as a neat plugin.


Here is a [presentation of the plugin on youtube](https://www.youtube.com/watch?v=7ug8cWKAuO8)

# How to install

To install this plugin, run the following commands.

<pre>
mkdir -p ~/.vim/pack/vendor/start/gitblame; git clone --depth 1 https://github.com/MoserMichael/gitblame ~/.vim/pack/vendor/start/gitblame
</pre>

or 

<pre>
mkdir -p ~/.vim/pack/vendor/start/gitblame 
git clone --depth 1 https://github.com/MoserMichael/gitblame ~/.vim/pack/vendor/start/gitblame
</pre> 

To install from the downloaded zip file: 

<pre>
mkdir -p ~/.vim/pack/vendor/start/gitblame; unzip gitblame.zip -d  ~/.vim/pack/vendor/start/gitblame
</pre>

To generate the help text run the following vim command:

```:helptags ALL```

After that you can view the help file of plugin via vim command:

```:help gitblame```

Also see this script on [vim.org](https://www.vim.org/scripts/script.php?script_id=5975)

# Acknowledgement

This plugin uses Redir by Romain Lafourcade https://gist.github.com/romainl/eae0a260ab9c135390c30cd370c20cd7

# Bugs

Showing the current git branch in the status line doesn't always work.
Sometimes the command to show the git branch is running too slow, in this case you will see nasty symbols while moving the cursor around the screen.
I saw this happening on Linux running under WSL, on Windows (didn't see it on Linux without WSL or on the Mac)


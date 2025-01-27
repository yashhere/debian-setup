# Copyright © 2019 Marcel Kapfer <opensource@mmk2410.org>
# MIT License

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

if status --is-interactive
    alias grep="grep --color=auto"
    alias df="df -h"
    alias du="du -c -h"
    alias mkdir="mkdir -p -v"
    alias ln="ln -i"
    alias chown="chown --preserve-root"
    alias chmod="chmod --preserve-root"
    alias chgrp="chgrp --preserve-root"
    alias ps="ps aux k%cpu"
    alias q="exit"
    alias Q="exit"
    alias x="exit"
    alias o="xdg-open"
    alias vim="nvim"
    alias e="es"
    alias pu="ps aux | grep -v grep | grep"
    alias rmdot="rm -rf .[!.]*"
    alias sudoedit="sudo $EDITOR"
    alias rs="exec $SHELL"
    alias pbpaste="xclip -selection clipboard -o"

    alias aider="aider --env-file $HOME/.aider.env"
end

function ls --wraps lsd --description "alias ls=lsd"
    if type -q lsd
        lsd $argv
    else
        command ls $argv
    end
end
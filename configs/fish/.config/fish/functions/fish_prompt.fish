# biras_weird_cousin
# Theme based on Bira theme from oh-my-zsh
# Some code stolen from oh-my-fish clearance theme

function __ssh_badge
    if test -n "$SSH_CLIENT$SSH2_CLIENT$SSH_TTY"
        set_color -b 9370DB -o black  # Lighter purple background, black text
        echo -n " "(string upper (string sub -s 1 -l 1 (hostname -s)))" "
        set_color normal
    end
end

function __ssh_host
    if test -n "$SSH_CLIENT$SSH2_CLIENT$SSH_TTY"
        set_color 444  # Darker gray for better contrast
        echo -n $USER@
        set_color normal
        set_color -o 8B008B  # Darker purple
        echo -n (hostname -s)
        set_color normal
    end
end

function __user_host
    if test (id -u) -eq 0
        set_color --bold red
    else
        set_color --bold 006400  # Darker green
    end
    echo -n $USER@(hostname -s) (set_color normal)
end

function __current_path
    set -l path (string replace "$HOME" (set_color 8B008B)"~"(set_color 444) (pwd))

    set repo (git rev-parse --show-toplevel 2>/dev/null)
    if not test "$repo" = ""
        set repo (string replace "$HOME" "" $repo)
        set path (string replace "$repo" (set_color 8B4513)"$repo"(set_color 444) $path)  # Darker yellow/brown
    end

    echo -n " "$path(set_color normal)
end

function _git_branch_name
    echo (command git symbolic-ref HEAD 2> /dev/null | sed -e 's|^refs/heads/||')
end

function _git_is_dirty
    echo (command git status -s --ignore-submodules=dirty 2> /dev/null)
end

function __git_status
    if [ (_git_branch_name) ]
        set -l git_branch (_git_branch_name)

        if [ (_git_is_dirty) ]
            set git_color "8B4513"  # Darker brown for dirty state
            set git_info '('$git_branch"*"')'
        else
            set git_color "006400"  # Darker green for clean state
            set git_info '('$git_branch')'
        end

        echo -n (set_color $git_color) $git_info (set_color normal)
    end
end

function fish_prompt -d '"Bira\'s weird cousin" prompt'
    set -l st $status
    set -l pchar (set_color --bold 444)"❯"  # Darker prompt character
    if [ $st != 0 ];
        set pchar (set_color --bold 8B0000)"❯"  # Darker red for error
    end

    echo -n (set_color 006400)"┌"(set_color normal)
    __ssh_badge
    __current_path
    __git_status
    echo -e ''

    echo -e (set_color 006400)"└─$pchar "(set_color normal)
end

function fish_right_prompt
    set -l st $status
    if [ $st != 0 ];
        echo (set_color 8B0000) ↵ $st (set_color normal)  # Darker red
    end
    __ssh_host
    if test "$CMD_DURATION" -gt 3000
        set_color 444  # Darker gray
        set -l duration (echo -n $CMD_DURATION | __human_time)
        printf ' (%s)' $duration
    end
    set_color 444  # Darker gray
    date '+ %T'
    set_color normal
end
function auto-commit
    if not command -v gh >/dev/null 2>&1
        echo "Error: GitHub CLI (gh) is not installed."
        return 1
    end

    if not gh extension list | grep -q "gh-commit"
        echo "Error: gh-commit extension is not installed."
        echo "Please install it using: gh extension install ghcli/gh-commit"
        return 1
    end

    git commit -m (gh commit) || git commit -a -m (gh commit)
    git log HEAD...HEAD~1
end
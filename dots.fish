# Fish completions for dots

complete -c dots -f

complete -c dots -n '__fish_use_subcommand' -a link -d 'Symlink shared scripts, completions, and configs'
complete -c dots -n '__fish_use_subcommand' -a status -d 'Symlink health and git status'
complete -c dots -n '__fish_use_subcommand' -a diff -d 'Uncommitted config changes'
complete -c dots -n '__fish_use_subcommand' -a brewfile -d 'Refresh Brewfile'
complete -c dots -n '__fish_use_subcommand' -a sync -d 'Refresh Brewfile, commit, and push'
complete -c dots -n '__fish_use_subcommand' -a pull -d 'Pull latest and re-link'
complete -c dots -n '__fish_use_subcommand' -a add -d 'Track a file and symlink it'
complete -c dots -n '__fish_use_subcommand' -a clean -d 'Prune stale .bak backups'
complete -c dots -n '__fish_use_subcommand' -a lint -d 'Syntax check and run tests'
complete -c dots -n '__fish_use_subcommand' -a schedule -d 'Weekly launchd run'
complete -c dots -n '__fish_use_subcommand' -a repo -d 'View or change the config repo'
complete -c dots -n '__fish_use_subcommand' -a path -d 'Print the config repo path'
complete -c dots -n '__fish_use_subcommand' -a version -d 'Print version'

complete -c dots -n '__fish_seen_subcommand_from add' -F -d 'File to track'
complete -c dots -n '__fish_seen_subcommand_from clean' -a '1 2 3 5 10' -d 'Backups to keep'
complete -c dots -n '__fish_seen_subcommand_from schedule' -a 'install status remove' -d 'Action'
complete -c dots -n '__fish_seen_subcommand_from schedule' -a '0 1 2 3 4 5 6 7' -d 'Hour of day'
complete -c dots -n '__fish_seen_subcommand_from repo' -a 'new' -d 'Create a new private Gist'
complete -c dots -n '__fish_seen_subcommand_from sync' -d 'Commit message'

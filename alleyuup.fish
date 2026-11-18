# Fish completions for alleyuup

complete -c alleyuup -f

set -l alleyuup_steps self-update brew mas agy claude opencode openclaw nvm npm pnpm rustup uv pipx gh-ext repos local-projects brewfile repo-sync shell macos

complete -c alleyuup -s h -l help -d 'Show help'
complete -c alleyuup -s v -l version -d 'Print version and git revision'
complete -c alleyuup -s n -l dry-run -d 'Preview changes without applying them'
complete -c alleyuup -l fast -d 'Skip macOS system updates'
complete -c alleyuup -l no-macos -d 'Skip macOS system updates'
complete -c alleyuup -l no-repos -d 'Skip git pulls in ~/code'
complete -c alleyuup -l no-self-update -d 'Skip pulling latest alleyuup'
complete -c alleyuup -l only -x -a "$alleyuup_steps" -d 'Run only these steps'
complete -c alleyuup -l skip -x -a "$alleyuup_steps" -d 'Skip these steps'
complete -c alleyuup -l repo -d 'Configure the machine config repo'
complete -c alleyuup -l config -d 'Edit the per-machine config'
complete -c alleyuup -l init-config -d 'Create the per-machine config without an editor'
complete -c alleyuup -l edit -d 'Edit the per-machine config'
complete -c alleyuup -l print-config -d 'Print the per-machine config'
complete -c alleyuup -l print-steps -d 'Print resolved step toggles'
complete -c alleyuup -l print-mappings -d 'Print tracked file mappings'
complete -c alleyuup -l check -d 'Check for updates on the remote'

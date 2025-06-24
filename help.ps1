@'
BORG HELP — Available Commands

USAGE:
    borg <module> <command> [options]

DOCKER COMMANDS:
    borg docker restore         (bdr | borg d r)     → Restore a `.bak` file into Docker SQL
    borg docker snapshot        (bds | borg d s)     → Create a snapshot from current container
    borg docker clean           (bdc | borg d c)     → Remove container + volume
    borg docker switch          (bdsw | borg d sw)   → Restore from snapshot (kills open connections)
    borg docker download        (bdd | borg d d)     → Download snapshot from container to host
    borg docker upload          (bdu | borg d u)     → Upload `.bak` file from host to container
    borg docker query           (bdq | borg d q)     → Execute ad-hoc SQL queries inside container
    borg docker shell                                → Open bash inside SQL container

GDRIVE COMMANDS:
    borg gdrive upload                               → Upload file from current folder to GDrive using fzf

NETWORK COMMANDS:
    borg network bacpac                              → Export `.bacpac` from defined SqlServer to local
    borg network kill                                → Kill process by port or name (optional -c to confirm)

JIRA COMMANDS:
    borg jira today                                  → Show today’s worklog
    borg jira week                                   → Show worklogs for current week
    borg jira latest [days]                          → Recently updated issues (default: 7 days)

UTILITY COMMANDS:
    borg doctor                                      → Validate environment & requirements
    borg store                                       → Open store.json config in editor
    borg update                                      → Update BORG module from gallery
    borg help                                        → Show this help page
    borg --version                                   → Show current + latest version
    borg clean versions                              → Remove older versions of BORG
    borg io folder-clean         (fc)                → Clean folders from store.json → CleanFolders

BOOKMARKING COMMANDS:
    borg bookmark                (b)                 → Fuzzy-jump to predefined bookmarks
    borg jump store                                  → Add current folder as bookmark (with alias)
    borg jump <alias>            (bj <alias>)        → Jump to folder via alias

CUSTOM SCRIPTS:
    borg run                                          → Fuzzy-run any script from your custom folder

'@

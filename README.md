# GitStatusPoshClient

PowerShell Module client for retrieving git repository information from [git-status-cache](https://github.com/cmarcusreid/git-status-cache). Communicates with the cache process via named pipe.

## :books: Informations

A minimal version of [git-status-posh-client](https://github.com/cmarcusreid/git-status-cache-posh-client) without the need for a [Chocolatey](https://chocolatey.org/) installation making full use of Powershell [Module Manifest](https://docs.microsoft.com/en-us/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest).
This module allows [posh-git](https://github.com/dahlbyk/posh-git) Module to access and cache git repositories status for a seamless use and without the need for any user to change anything because they are already integrated in posh-git.


## :tada: Installation

### With my Dotfiles

The complete use of this module alongside others is managed by my personal [Dotfile configuration](https://github.com/LeoCalbi/dotfiles) managed with [Chezmoi](https://www.chezmoi.io/).

### With git

Execute:

```powershell
git clone https://github.com/LeoCalbi/GitStatusPoshClient.git
$ModuleFolder = ($Env:PSModulePath | Split-String -Separator ";")[0]
Move-Item -Path GitStatusPoshClient\GitStatusPoshClient -Destination $ModuleFolder
Remove-Variable -Name "ModuleFolder"
```

Then add to your Powershell Profile (Path at `$Profile`):

```powershell
Import-Module MyUtilities
```

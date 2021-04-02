# Powershell completion script for pdm

if ((Test-Path Function:\TabExpansion) -and -not (Test-Path Function:\_pdm_completeBackup)) {
    Rename-Item Function:\TabExpansion _pdm_completeBackup
}

$PDM_PYTHON = "D:\Workspace\pdm\venv\Scripts\python.exe"

class Option {
    [string[]] $Opts
    [string[]] $Values

    Option([string[]] $opts) {
        $this.Opts = $opts
    }

    [Option] WithValues([string []] $values) {
        $this.Values = $values
        return $this
    }

    [bool] Match([string] $word) {
        foreach ($opt in $this.Opts) {
            if ($word -eq $opt) {
                return $true
            }
        }
        return $false
    }

    [bool] TakesArg() {
        return $null -ne $this.Values
    }
}

class Completer {

    [string []] $params
    [bool] $multiple = $false
    [Option[]] $opts = @()

    Completer() {
    }

    [string[]] Complete([string[]] $words) {
        $expectArg = $null
        $lastWord = $words[-1]
        $paramUsed = $false
        foreach ($word in $words[0..-2]) {
            if ($expectArg) {
                $expectArg = $null
                continue
            }
            if ($word.StartsWith("-")) {
                $opt = $this.opts.Where( { $_.Match($word) })[0]
                if ($null -ne $opt -and $opt.TakesArg()) {
                    $expectArg = $opt
                }
            }
            elseif (-not $this.multiple) {
                $paramUsed = $true
            }
        }
        $candidates = @()
        if ($lastWord.StartsWith("-")) {
            foreach ($opt in $this.opts) {
                $candidates += $opt.Opts
            }
        }
        elseif ($null -ne $expectArg) {
            $candidates = $expectArg.Values
        }
        elseif ($null -ne $this.params -and -not $paramUsed) {
            $candidates = $this.params
        }
        return $candidates.Where( { $_.StartsWith($lastWord) })
    }

    [Completer] addOpts([Option[]] $options) {
        $this.opts += $options
        return $this
    }

    [Completer] addParams([string[]] $params, [bool]$multiple = $false) {
        $this.params = $params
        $this.multiple = $multiple
        return $this
    }
}

function getSections() {
    return @()
}

function getPyPIPackages() {
    return @()
}

function getPdmPackages() {
    return @()
}

function getConfigKeys() {
    [string[]] $keys = @()
    $config = ("& $PDM_PYTHON -m pdm config")
    foreach ($line in $($config -split "`r`n")) {
        if ($line -match ' *(\s+) *=') {
            $keys += $Matches[1]
        }
    }
    return $keys
}

function getScripts() {
    return @()
}

function TabExpansion($line, $lastWord) {
    $lastBlock = [regex]::Split($line, '[|;]')[-1].TrimStart()

    if ($lastBlock -match "^pdm ") {
        $words = $lastBlock.Split()[1..-1]
        $commands = $words.Where( { $_ -notlike "-*" })
        $command = $commands[0]
        $completer = [Completer]::new().addOpts(([Option]::new(("-h", "--help", "-v", "--verbose"))))
        $sectionOption = [Option]::new(@("-s", "--section")).WithValues(@(getSections))
        $projectOption = [Option]::new(@("-p", "--project")).WithValues(@())
        $formatOption = [Option]::new(@("-f", "--format")).WithValues(@("setuppy", "requirements", "poetry", "flit"))

        Switch ($command) {

            "add" {
                $completer.addOpts(@(
                        [Option]::new(("-d", "--dev", "--save-compatible", "--save-wildcard", "--save-exact", "--update-eager", "--update-reuse", "-g", "--global", "--no-sync")),
                        $sectionOption,
                        $projectOption,
                        [Option]::new(@("-e", "--editable")).WithValues(@(getPyPIPackages))
                    )).addParams(@(getPyPIPackages))
            }
            "build" { $completer.addOpts(@([Option]::new(@("-d", "--dest", "--no-clean", "--no-sdist", "--no-wheel")), $projectOption)) }
            "cache" {
                $subCommand = $commands[1]
                switch ($subCommand) {
                    "clear" {
                        $completer.addParams(@("wheels", "http", "hashes", "metadata"))
                        $command = $subCommand
                    }
                    $null {
                        $completer.addParams(@("clear", "remove", "info", "list"))
                    }
                    Default {}
                }
            }
            "completion" { $completer.addParams(@("powershell", "bash", "zsh", "fish")) }
            "config" { $completer.addOpts(@([Option]::new(@("--delete", "--global", "--local", "-d", "-l", "-g")), $projectOption)) }
            "export" {
                $completer.addOpts(@(
                        [Option]::new(@("--dev", "--output", "--global", "--no-default", "-g", "-d", "-o", "--without-hashes")),
                        $formatOption,
                        $sectionOption,
                        $projectOption
                    ))
            }
            "import" {
                $completer.addOpts(@(
                        [Option]::new(@("--dev", "--global", "--no-default", "-g", "-d")),
                        $formatOption,
                        $sectionOption,
                        $projectOption
                    ))
            }
            "info" {
                $completer.addOpts(
                    @(
                        [Option]::new(@("--env", "--global", "-g", "--python", "--where", "--packages")),
                        $projectOption
                    ))
            }
            "init" {
                $completer.addOpts(
                    @(
                        [Option]::new(@("-g", "--global", "--non-interactive", "-n")),
                        $projectOption
                    ))
            }
            "install" {
                $completer.addOpts(@(
                        [Option]::new(("-d", "--dev", "-g", "--global", "--no-default", "--no-lock")),
                        $sectionOption,
                        $projectOption
                    ))
            }
            "list" {
                $completer.addOpts(
                    @(
                        [Option]::new(@("--graph", "--global", "-g", "--reverse", "-r")),
                        $projectOption
                    ))
            }
            "lock" {
                $completer.addOpts(
                    @(
                        [Option]::new(@("--global", "-g")),
                        $projectOption
                    ))
            }
            "remove" {
                $completer.addOpts(
                    @(
                        [Option]::new(@("--global", "-g", "--dev", "-d", "--no-sync")),
                        $projectOption,
                        $sectionOption
                    )).addParams(@(getPdmPackages))
            }
            "run" {
                $completer.addOpts(
                    @(
                        [Option]::new(@("--global", "-g", "-l", "--list")),
                        $projectOption
                    )).addParams(@(getScripts))
            }
            "search" { }
            "show" {
                $completer.addOpts(
                    @(
                        [Option]::new(@("--global", "-g")),
                        $projectOption
                    ))
            }
            "sync" {
                $completer.addOpts(@(
                        [Option]::new(("-d", "--dev", "-g", "--global", "--no-default", "--clean", "--no-clean", "--dry-run")),
                        $sectionOption,
                        $projectOption
                    ))
            }
            "update" {
                $completer.addOpts(@(
                        [Option]::new(("-d", "--dev", "--save-compatible", "--save-wildcard", "--save-exact", "--update-eager", "--update-reuse", "-g", "--global", "--dry-run", "--outdated", "--top")),
                        $sectionOption,
                        $projectOption
                    )).addParams(@(getPdmPackages))
            }
            "use" {
                $completer.addOpts(
                    @(
                        [Option]::new(@("--global", "-g", "-f", "--first")),
                        $projectOption
                    ))
            }

            default {
                # No command
                $completer.addParams(@("add", "build", "cache", "config", "export", "import", "info", "init", "install", "list", "lock", "remove", "run", "search", "show", "sync", "update", "use"))
            }
        }
        $completer.Complete($words[[array]::IndexOf($words, $command) + 1..-1])
    }
    elseif (Test-Path Function:\_pdm_completeBackup) {
        # Fall back on existing tab expansion
        _pdm_completeBackup $line $lastWord
    }
}

TabExpansion "pdm config " ""

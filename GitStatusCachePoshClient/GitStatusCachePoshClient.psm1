<#
        .SYNOPSIS
        PowerShell client for retrieving git repository information from git-status-cache. Communicates with the cache process via named pipe.
#>
# -----------------------------------------------------------------------------
#                     GitStatusCachePoshClient
# -----------------------------------------------------------------------------

#                              Notes
# -----------------------------------------------------------------------------
# Ispired from Marcus Reid edited by Leonardo Calbi
# https://github.com/cmarcusreid/git-status-cache-posh-client

#                               Aliases
# -----------------------------------------------------------------------------

#                              Functions
# -----------------------------------------------------------------------------
Function Get-BinPath {
	return Join-Path $PSScriptRoot "bin"
}

Function Get-ExecutablePath {
	$binPath = Get-BinPath
	return Join-Path $binPath "GitStatusCache.exe"
}

Function Remove-GitStatusCache {
	$process = Get-Process -Name "GitStatusCache" -ErrorAction SilentlyContinue
	if ($null -ne $process) {
		Stop-Process -Name "GitStatusCache" -Force -ErrorAction SilentlyContinue
		Start-Sleep -m 50
	}

	$binPath = Get-BinPath
	if (Test-Path $binPath) {
		Remove-Item -Path $binPath -Force -Recurse -ErrorAction Stop
	}
}

Function Test-Release($release) {
	# This script understands the named pipe protocol used by V1 git-status-cache releases.
	if (-not $release.tag_name.StartsWith("v1.")) {
		return $false
	}

	foreach ($asset in $release.assets) {
		if ($asset.browser_download_url.EndsWith("GitStatusCache.exe")) {
			return $true;
		}
	}

	return $false
}

Function Get-ExecutableDownloadUrl {
	$release = wget -Uri "https://api.github.com/repos/cmarcusreid/git-status-cache/releases/latest" | ConvertFrom-Json
	if (-not (Test-Release $release)) {
		Write-Host -ForegroundColor Yellow "Latest git-status-cache release is not compatible with this version of git-status-cache-posh-client."
		Write-Host -ForegroundColor Yellow "Please update git-status-cache-posh-client."
		Write-Host -ForegroundColor Yellow "Falling back to latest compatible release of git-status-cache."
		$allReleases = wget -Uri "https://api.github.com/repos/cmarcusreid/git-status-cache/releases" | ConvertFrom-Json | Sort-Object -Descending -Property "published_at"
		foreach ($candidateRelease in $allReleases) {
			if (Test-Release $candidateRelease) {
				$release = $candidateRelease
				break
			}
		}
	}
	foreach ($asset in $release.assets) {
		if ($asset.browser_download_url.EndsWith("GitStatusCache.exe")) {
			return $asset.browser_download_url;
		}
	}
	Write-Error "Failed to find GitStatusCache.exe download URL."
}

Function Update-GitStatusCache {
	Remove-GitStatusCache
	$binPath = Get-BinPath
	if (-not (Test-Path $binPath)) {
		Write-Host -ForegroundColor Green "Creating directory for GitStatusCache.exe at $binPath."
		New-Item -ItemType Directory -Force -Path $binPath -ErrorAction Stop | Out-Null
	}

	$executablePath = Get-ExecutablePath
	if (Test-Path $executablePath) {
		Remove-Item "$executablePath"
	}

	Write-Host -ForegroundColor Green "Downloading $executablePath."
	$executableUrl = Get-ExecutableDownloadUrl
	wget -Uri $executableUrl -OutFile "$executablePath"
}

Function Start-GitStatusCache {
	$process = Get-Process -Name "GitStatusCache" -ErrorAction SilentlyContinue
	if ($null -eq $process) {
		$executablePath = Get-ExecutablePath
		if (-not (Test-Path $executablePath)) {
			Throw [System.InvalidOperationException] "GitStatusCache.exe was not found. Call Update-GitStatusCache to download."
			return $false
		}
		Start-Process -FilePath $executablePath
	}
}

Function Disconnect-Pipe {
	$global:GitStatusCacheClientPipe.Dispose()
	$global:GitStatusCacheClientPipe = $null
}

Function Connect-Pipe {
	if ($null -ne $global:GitStatusCacheClientPipe -and -not $global:GitStatusCacheClientPipe.IsConnected) {
		Disconnect-Pipe
	}

	if ($null -eq $global:GitStatusCacheClientPipe) {
		Start-GitStatusCache
		$global:GitStatusCacheClientPipe = New-Object System.IO.Pipes.NamedPipeClientStream '.', 'GitStatusCache', 'InOut', 'WriteThrough'
		$global:GitStatusCacheClientPipe.Connect(100)
		$global:GitStatusCacheClientPipe.ReadMode = 'Message'
	}
}

Function Send-RequestToGitStatusCache($requestJson) {
	Connect-Pipe

	$remainingRetries = 1
	while ($remainingRetries -ge 0) {
		$encoding = [System.Text.Encoding]::UTF8
		$requestBuffer = $encoding.GetBytes($requestJson)

		$wasPipeBroken = $false
		try {
			$global:GitStatusCacheClientPipe.Write($requestBuffer, 0, $requestBuffer.Length)
		}
		catch [system.io.ioexception] {
			Disconnect-Pipe
			Connect-Pipe
			--$remainingRetries
			$wasPipeBroken = $true
		}

		if (-not $wasPipeBroken) {
			$chunkSize = $global:GitStatusCacheClientPipe.InBufferSize
			$totalBytesRead = 0
			$responseBuffer = $null
			do {
				$chunk = New-Object byte[] $chunkSize
				$bytesRead = $global:GitStatusCacheClientPipe.Read($chunk, 0, $chunkSize)
				$totalBytesRead += $bytesRead

				if ($null -eq $responseBuffer) {
					$responseBuffer = $chunk
				}
				else {
					$responseBuffer += $chunk
				}
			} while ($bytesRead -eq $chunkSize)

			$response = $encoding.GetString($responseBuffer, 0, $totalBytesRead)
			$responseObject = ConvertFrom-Json $response
			return $responseObject
		}
	}
}

Function Stop-GitStatusCache {
	$request = New-Object psobject -property @{ Version = 1; Action = "Shutdown" } | ConvertTo-Json -Compress
	return Send-RequestToGitStatusCache($request)
}

Function Restart-GitStatusCache {
	Stop-GitStatusCache
	Connect-Pipe
}

Function Get-GitStatusFromCache {
	$request = New-Object psobject -property @{ Version = 1; Action = "GetStatus"; Path = (Get-Location).Path } | ConvertTo-Json -Compress
	return Send-RequestToGitStatusCache($request)
}

Function Get-GitStatusCacheStatistics {
	$request = New-Object psobject -property @{ Version = 1; Action = "GetCacheStatistics"; } | ConvertTo-Json -Compress
	return Send-RequestToGitStatusCache($request)
}

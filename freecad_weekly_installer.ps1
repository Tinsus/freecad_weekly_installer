#TODO:

$Script_path = Split-Path $MyInvocation.Mycommand.Path -Parent
$checkfile = "$Script_path\checkfile"

function removefile($path) {
	Remove-Item "$path" -recurse -force -ErrorAction SilentlyContinue
}

function newdir($path) {
	New-Item "$path" -ItemType Directory -ErrorAction SilentlyContinue
}

function nls($total) {
	for ($i = 0; $i -lt $total; $i++) {
		Write-Host " "
	}
}

function Get-IniContent($filePath) {
    $ini = @{}

    Switch -regex -file $FilePath {
		# Section
        "^\[(.+)\]" {
            $section = $matches[1]
            $ini[$section] = @{}
            $CommentCount = 0
        }
		# Comment
        "^(;.*)$" {
            $value = $matches[1]
            $CommentCount = $CommentCount + 1
            $name = "Comment" + $CommentCount
            $ini[$section][$name] = $value
        }
		# Key
        "(.+?)\s*=(.*)" {
            $name, $value = $matches[1..2]

			if (($value -eq "True") -or ($value -eq "False")) {
				$value = ($value -eq "True")
			}

            $ini[$section][$name] = $value
        }
    }

    return $ini
}

function Out-IniFile($InputObject, $FilePath) {
	$newlines = @()

    foreach ($i in $InputObject.keys) {
        if (!($($InputObject[$i].GetType().Name) -eq "Hashtable")) {
            #No Sections
            $newlines += "$i=$($InputObject[$i])"
        } else {
            #Sections
            $newlines += "[$i]"

            Foreach ($j in ($InputObject[$i].keys | Sort-Object)) {
                if ($j -match "^Comment[\d]+") {
                    $newlines += "$($InputObject[$i][$j])"
                } else {
                    $newlines += "$j=$($InputObject[$i][$j])"
                }
            }

            $newlines += ""
        }
    }

#	removefile $FilePath
    $newlines | Out-File $Filepath
}

#get dependencies

if (-not (Get-Module -ListAvailable -Name 7Zip4PowerShell)) {
	nls 6
	Write-Host "Please wait a moment - we need to add some dependencies. This is needed once only."
	nls 1

	if (-not (Get-PackageProvider -ListAvailable -Name NuGet)) {
		Install-PackageProvider -Name NuGet -Force -Scope CurrentUser
	}

    Install-Module -Name 7Zip4PowerShell -Scope CurrentUser -Force
}

#some "welcoming" text
Clear-Host
nls 6
Write-Host "Before we can do any nice stuff let us see what nice stuff is out there."
nls 1

#build config


if (Test-Path "$Script_path\freecad_weekly_installer.ini") {
	$conf = Get-IniContent "$Script_path\freecad_weekly_installer.ini"
} else {
	$conf = @{}
	$conf.version = @{}
}

# check githubs API restrictions and waits until it's possible again
Invoke-WebRequest "https://api.github.com/rate_limit" -OutFile "$Script_path\github.json"
$json = (Get-Content "$Script_path\github.json" -Raw) | ConvertFrom-Json
removefile "$Script_path\github.json"

if ($json.rate.remaining -lt 1) {
	nls 3
	Write-Host "No more updates possible due to API limitations by github.com :(" -ForegroundColor Red
	nls 3
	Write-Host "FreeCAD will not been updated, so just keep going."

	Start-Process -FilePath "$Script_path\FreeCAD\bin\freecad.exe" -WorkingDirectory "$Script_path\FreeCAD\bin\" -ErrorAction SilentlyContinue

	Start-Sleep -Seconds 2
	exit
}

nls 2

# auto update this script itself (prepare the update to be done by the .bat file with the next start)
Write-Host "freecad_weekly_installer.bat " -NoNewline -ForegroundColor White
Write-Host "is " -NoNewline
Write-Host "updated " -NoNewline -ForegroundColor Green
Write-Host "every time"

removefile "$Script_path\freecad_weekly_installer.bat"
Invoke-WebRequest "https://github.com/Tinsus/freecad_weekly_installer/raw/main/freecad_weekly_installer.bat" -OutFile "$Script_path/freecad_weekly_installer.bat"

# get FreeCAD version and download links
$checkurl = "https://api.github.com/repos/FreeCAD/FreeCAD-Bundle/releases/tags/weekly-builds"
Invoke-WebRequest "$checkurl" -OutFile "$checkfile"

$json = (Get-Content "$checkfile" -Raw) | ConvertFrom-Json
removefile "$checkfile"

$download = 0
$size = 0
$new = 0

$json.assets | foreach {
	if (
		($_.browser_download_url -like "*windows*") -and
		($_.browser_download_url -like "*.7z") -and
		-not (($_.browser_download_url -like "*.txt"))
	) {
		$download = $_.browser_download_url
		$size = $_.size
		$new = $_.created_at
	}
}

if ($download -eq 0) {
	nls 5
	Write-Host "No download for windows could be found." -ForegroundColor Red
	nls 2
	Write-Host "If this seems to be an error report it at: https://github.com/Tinsus/freecad_weekly_installer/issues" -ForegroundColor Yellow

	Start-Sleep -Seconds 2
} else {
	if (
		($conf.version.Freecad -eq $null) -or
		($conf.version.Freecad -ne $new) -or
		(-not (Test-Path "$Script_path\FreeCAD\bin\freecad.exe"))
	) {
		Write-Host "FreeCAD " -NoNewline -ForegroundColor White
		Write-Host "gets an " -NoNewline
		Write-Host "update" -ForegroundColor Green

		#download FreeCAD
		nls 1
		Write-Host "Download is running. Please wait, until the Bytes downloaded reach " -NoNewline
		Write-Host $size -ForegroundColor Yellow

		Invoke-WebRequest $download -OutFile "$checkfile.7z"

		Write-Host "Download finished" -ForegroundColor Green

		#"installing" FreeCAD
		nls 1
		Write-Host "Extracting the downloaded files"

		removefile "$Script_path\unzipped\"
		removefile "$Script_path\FreeCAD\"
		newdir "$Script_path\unzipped\"

		Expand-7Zip -ArchiveFileName "$checkfile.7z" -TargetPath "$Script_path\unzipped\"

		$child = $(gci "unzipped\" -Directory).Name

		Move-Item "$Script_path\unzipped\$child" "$Script_path\FreeCAD"

		$stamp = $new -replace ":", ""

		Move-Item "$checkfile.7z" "$Script_path\$stamp.7z"
		removefile "$Script_path\unzipped\"

		Write-Host "Update finished" -ForegroundColor Green

		$conf.version.Freecad = $new
		Out-IniFile -InputObject $conf -FilePath "$Script_path\freecad_weekly_installer.ini"
	} else {
		Write-Host "FreeCAD " -NoNewline -ForegroundColor White
		Write-Host "is " -NoNewline
		Write-Host "up to date" -ForegroundColor White
	}
}

# done with updating
Start-Process -FilePath "$Script_path\FreeCAD\bin\freecad.exe" -WorkingDirectory "$Script_path\FreeCAD\bin\" -ErrorAction SilentlyContinue

nls 1
Write-Host "I have other stuff to do"

Start-Sleep -Seconds 18
exit

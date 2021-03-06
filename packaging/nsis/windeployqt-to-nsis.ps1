# windeployqt-to-nsh
#
# Windeployqt-to-nsh - Convert the output of windeployqt to an equivalent set of
# NSIS "File" function calls.
#
# Copyright 2014 Gerald Combs <gerald@wireshark.org>
#
# Wireshark - Network traffic analyzer
# By Gerald Combs <gerald@wireshark.org>
# Copyright 1998 Gerald Combs
#
# SPDX-License-Identifier: GPL-2.0-or-later

#requires -version 2

<#
.SYNOPSIS
Creates NSIS "File" function calls required for Qt packaging.

.DESCRIPTION
This script creates an NSIS-compatible file based on the output of
windeployqt. If Qt is present, version 5.3 or later is required.
Otherwise a dummy file will be created.

If building with Qt, QMake must be in your PATH.

.PARAMETER Executable
The path to a Qt application. It will be examined for dependent DLLs.

.PARAMETER FilePath
Output filename.

.PARAMETER DebugConfig
Assume debug binaries.

.INPUTS
-Executable Path to the Qt application.
-FilePath Output NSIS file.

.OUTPUTS
List of NSIS commands required to package supporting DLLs.

.EXAMPLE
C:\PS> .\windeployqt-to-nsis.ps1 windeployqt.exe ..\..\staging\wireshark.exe qt-dll-manifest.nsh [-DebugConfig]
#>

Param(
    [Parameter(Mandatory=$true, Position=0)]
    [String] $Executable,

    [Parameter(Position=1)]
    [String] $FilePath = "qt-dll-manifest.nsh",

    [Parameter(Mandatory=$false)]
    [Switch] $DebugConfig
)


try {
    $qtVersion = [version](qmake -query QT_VERSION)
    $nsisCommands = @("# Qt version " + $qtVersion ; "#")

    if ($qtVersion -lt "5.3") {
        Throw "Qt " + $qtVersion + " found. 5.3 or later is required."
    }

    $DebugOrRelease = If ($DebugConfig) {"--debug"} Else {"--release"}

    $wdqtList = windeployqt `
        $DebugOrRelease `
        --no-compiler-runtime `
        --list relative `
        $Executable

    $dllPath = Split-Path -Parent $Executable

    $dllList = @()
    $dirList = @()

    foreach ($entry in $wdqtList) {
        $dir = Split-Path -Parent $entry
        if ($dir) {
            $dirList += "File /r `"$dllPath\$dir`""
        } else {
            $dllList += "File `"$dllPath\$entry`""
        }
    }

    $dirList = $dirList | Sort-Object | Get-Unique

    $nsisCommands += $dllList + $dirList
}

catch {

    $nsisCommands = @"
# Qt not configured
#
"@

}

Set-Content $FilePath @"
#
# Automatically generated by $($MyInvocation.MyCommand.Name)
#
"@

Add-Content $FilePath $nsisCommands

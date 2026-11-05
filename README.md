# MasterImageCreation

`MasterImageCreation` is a PowerShell module designed to automate the end-to-end process of building and provisioning master virtual machine images and application packages for **Omnissa Horizon View** and **Omnissa Application Volumes** environments.

---

## Features

- **Multi-Phase Base Image Orchestration:** Automates software installation, driver deployment, OSOT (OS Optimization Tool) optimization, generalize/finalize steps, and automated reboots across multiple phases.
- **Data Center & Domain Configuration:** Supports multi-datacenter configurations (VCenters, Connection Servers, App Volumes Managers, FSLogix paths).
- **Flexible Application Deployment:** Define application install configurations using Winget, Evergreen, Direct Downloads, or local files.
- **Omnissa App Volumes Packaging:** Automate application package creation for App Volumes using reusable application library templates.

---

## Quickstart Guide

### Step 1: Install the PowerShell Module

Install the `MasterImageCreation` module directly from PowerShell:

```powershell
Install-Module -Name MasterImageCreation -Scope AllUsers -Force
```

---

### Step 2: Export Default Templates

Export the template scripts, JSON configurations, and folder structures to your central network share or local repository directory:

```powershell
Export-Templates -Path "\\contoso.com\horizon\Master"
```

> **Note:** The target UNC path will host your core script files, application library (`AppLibrary`), package templates (`AppPackage`), and software installation media.

---

### Step 3: Modify `BaseFile.json`

Update `BaseFile.json` to match your infrastructure requirements.

1. **Datacenter Settings (`DC`):** Set up target vCenter servers, Horizon Connection Servers, App Volumes Manager nodes, FSLogix share paths, and OSOT settings for each site (e.g., `Indianapolis`, `Columbus`).
2. **Variables & Copy Actions:** Configure `RemoteRoot` and `LocalRoot` paths as well as driver/software paths.
3. **Phases (0–4):** Adjust pre-script blocks, post-script blocks, core applications, and registry settings configured for each phase of image creation.

```json
{
    "Version": 2,
    "DC": {
        "Domain": "YOURDOMAIN.COM",
        "YourDataCenter": {
            "VCSA": "vcenter.yourdomain.com",
            "ConnectionServers": [
                "horizon1.yourdomain.com"
            ],
            "AppVol": {
                "Manager1": "appvol1.yourdomain.com",
                "Manager2": "appvol2.yourdomain.com"
            },
            "FSLogixPaths": [
                "\\\\share.yourdomain.com\\Profiles"
            ]
        }
    }
}
```

---

### Step 4: Configure `Start-BaseCreation.ps1`

Edit `Start-BaseCreation.ps1` to set the default values for `RemoteRoot`, `LocalRoot`, and target datacenter parameters to align with your setup:

```powershell
Param(
    [Parameter()]
    [System.IO.FileSystemInfo]$BaseFile,

    [Parameter()]
    [System.IO.FileSystemInfo]$OverlayFile,

    [Parameter()]
    [ValidateSet("YourDC1", "YourDC2")]
    [String]$DC,

    [Parameter()]
    [Switch]$JoinAAD,

    [Parameter()]
    [Switch]$Pause,

    [Parameter()]
    [String]$LocalRoot = "C:\Temp",

    [Parameter()]
    [String]$RemoteRoot = "\\yourdomain.com\horizon\Master"
)
```

To run the master image build on a the master image VM:

```powershell
.\Start-BaseCreation.ps1 -DC "YourDC1"
```

---

### Step 5: Add Application Definitions (`AppLibrary`)

Create custom JSON application definitions inside the `AppLibrary` folder using `ApplicationTemplate.json` as a guide.

#### Example Application Schema (`AppLibrary\7zip.json`)

```json
{
    "Name": "7zip",
    "Source": {
        "Evergreen":  [
                        {
                            "PreScriptblocks":  [

                                                ],
                            "Name":  "7Zip",
                            "Filter":  "$_.Architecture -eq \"x64\" -and $_.Type -eq \"msi\"",
                            "PostScriptblocks":  [

                                                ]
                        }
                    ],
    },
    "Install": [
        {
            "PreScriptblocks":  [

                                ],
            "Path":  "[SoftwarePath]\\7zip\\7z*.msi",
            "Arguments":  "/qn",
            "Recurse":  true,
            "PostScriptblocks":  [

                                    ]
        }
    ],
    "Detection": {
        "DisplayName": {
            "Architecture": "x64",
            "Name": "7-Zip"
        }
    }
}
```

---

### Step 6: Create Application Package Definitions (`AppPackage`)

Define multi-app packages in the `AppPackage` directory for use with **Omnissa Application Volumes**. Refer to `PackageTemplate.json` to organize bundles.

#### Example Package Definition (`AppPackage\Standard.json`)

```json
{
    "Name": "StandardAppPackage",
    "Variables": [
        {
            "Name": "LibraryPath",
            "Value": "C:\\Temp\\Scripts\\AppLibrary"
        },
        {
            "Name": "SoftwarePath",
            "Value": "C:\\Temp\\Software"
        }
    ],
    "PreScriptBlocks": [],
    "Applications": [
        "7zip",
        "GoogleChrome",
        "MicrosoftPowerBIDesktop",
        "MozillaFirefox",
        "NotepadPlusPlus",
        "PuTTY",
        "WinSCP"
    ],
    "PostScriptBlocks": []
}
```

---

## Execution Workflow Overview

1. **Phase 0:** Copies scripts/software to local target, installs VC Redistributables, system drivers, printer drivers, primary applications, and registry policies.
2. **Phase 1:** Installs Horizon Agent and Omnissa DEM (Dynamic Environment Manager).
3. **Phase 2:** Executes initial OS Optimization Tool (`OSOT -generalize`).
4. **Phase 3:** Synchronizes time, installs App Volumes Agent and FSLogix, and runs `OSOT -optimize`.
5. **Phase 4:** Installs Teams, configures antivirus exclusions, clears temporary user desktop files/software folders, runs `OSOT -Finalize All`, and shuts down the VM for snapshotting.
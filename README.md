# MasterImageCreation

`MasterImageCreation` is a PowerShell module designed to automate the end-to-end process of building and provisioning master virtual machine images and application packages for **Omnissa Horizon View** and **Omnissa Application Volumes** environments. This project is built to standardize and bootstrap the creation of master images for horizon VDI. The best practices detailed in [Manually creating optimized Windows images for Horizon VMs](https://techzone.omnissa.com/resource/manually-creating-optimized-windows-images-horizon-vms#overview-of-the-procedure-to-build-a-golden-image) are followed to the best extent possible.

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
        "YourDataCenter1": {
            "VCSA": "vcenter.yourdomain.com",
            "ConnectionServers": [
                "horizon1.yourdomain.com"
            ],
            "AppVol": {
                "Manager1": "appvol1.yourdomain.com",
                "Manager2": "appvol2.yourdomain.com"
            },
            "NVIDIALicensingServer":"",
            "FSLogixPaths":[
                "\\\\INDfs01.contoso.com\\Profiles",
                "\\\\COLfs01.contoso.com\\Profiles"
            ],
            "OSOT":{
                "Optimize":{
                    "Refernce":"https://docs.omnissa.com/bundle/Optimizing-Images-for-Horizon/page/OptimizationParameters.html",
                    "UseSettings":  false,
                    "SettingsJSON": ""
                }
            }
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
    [ValidateSet("YourYourDataCenter1", "YourDataCenter2")]
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

Create custom JSON application definitions inside the `AppLibrary` folder using `ApplicationTemplate.json` as a guide. The template contains all possible objects that define an application. Remove any that are unneeded, maintaining proper JSON syntax.

#### Example Application Schema (`AppLibrary\7zip.json`)

```json
{
    "Name": "7zip",
    "Source": {
        "Evergreen":  [
            {
                "Name":  "7Zip",
                "Filter":  "$_.Architecture -eq \"x64\" -and $_.Type -eq \"msi\"",
            }
        ]
    },
    "Install": [
        {
            "Path":  "[SoftwarePath]\\7zip\\7z*.msi",
            "Arguments":  "/qn",
            "Recurse":  true
        }
    ],
    "Detection": {
        "DisplayName": [
            {
                "Architecture": "x64",
                "Name": "7-Zip"
            }
        ]
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

All shell output is logged via Start-Transcript to `[LocalRoot]\Phase-#.log`

1. **Phase 0:** Copies scripts/software to local target, installs VC Redistributables, system drivers, printer drivers, primary applications, and registry policies.
2. **Phase 1:** Installs Horizon Agent and Omnissa DEM (Dynamic Environment Manager).
3. **Phase 2:** Executes initial OS Optimization Tool (`OSOT -generalize`).
4. **Phase 3:** Synchronizes time, installs App Volumes Agent and FSLogix, and runs `OSOT -optimize`.
5. **Phase 4:** Installs Teams, configures antivirus exclusions, clears temporary user desktop files/software folders, runs `OSOT -Finalize All`, and shuts down the VM for snapshotting.

---

## Building a master image

### Prereq: Create Template VM
These steps should only need to be executed either when moving from one `Windows 11 Feature Update` or to new `VMware Tools`.

1. Create virtual machine per [Manually creating optimized Windows images for Horizon VMs](https://techzone.omnissa.com/resource/manually-creating-optimized-windows-images-horizon-vms#overview-of-the-procedure-to-build-a-golden-image)
2. Install Windows and enter into Audit Mode during the OOBE
3. Configure OS
    + Install `Generic / Text Only` printer driver
    + Disable Bitlocker
    ```powershell
    Disable-BitLocker -MountPoint c:
    ```

    + Enable .NET 3.5
    ```cmd
    DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:d:\sources\sxs
    ```
    + Install VMWare Tools
        + Deselect Components:
            + VMware Carbon Black Helper
            + Service Discovery
            + Volume Shadow Copy Services Support
4. Reboot
5. Shutdown the VM
6. Remove the CD Drive from the VM
7. Convert the VM to a Template

### Step 1: Clone the Template VM

In vCenter, find your template and `right click` > click `New VM from template`. Once you have provided a `Name`, and selected `Folder`, `Compute`, and `Storage` click through the rest of the prompts. Once the VM is created, open the `Console` of the VM.

### Step 2: Establish connection to Remote Root and open PowerShell

In the console of the vm, Navigate to Scripts folder `[RemoteRoot]\Scripts`. Use domain credentials when prompted.
```powershell
\\fs.yourdomain.com\horizon\Master\Scripts
```
In the Address Bar of File Explorer, type `powershell.exe` and press enter. This will bring up shell prompt in the location from File Explorer.

> **Note:** Alternative methods exist to establish the connection and navigate via PowerShell.

### Step 3: Execute Start-BaseCreation.PS1

If you have edited `Start-BaseCreation.PS1` and:
+ Modified the `ValidateSet` for the DC parameter to match the DataCenter names in the BaseFile.JSON
+ provided the default values for `LocalRoot` and `RemoteRoot` execute:
```powershell
PS \\fs.yourdomain.com\Horizon\Master\Scripts>.\Start-BaseCreation.PS1 -DC "YourDataCenter1"
```

### Step 4: Wait for VM Powered Off

### Step 5: Take snapshot and deploy

Once the process is completed, the VM will be in a `Powered Off` state. You may now snapshot the VM and either Clone or Deploy the VM to Horizon.
# README — Build Automation Configuration (summary for customer)

Purpose
- This JSON is a single-environment automation manifest used to build, optimize, and generalize Windows master images for VMware Horizon.
- It defines environment variables, software to download/install, drivers, registry tweaks, OS optimization settings (OSOT), and a multi-phase orchestration (phases 0–4) including pre/post scripts and reboots.

Top-level items to know
- DC: domain and site-specific settings (SCRMC.LOC, srvviewvc01). Some values are blank and must be completed (ConnectionServers, AppVol managers, NVIDIALicensingServer, FSLogixPaths).
- PrinterDrivers / ZebraDrivers: large list of drivers to initialize. PrinterDrivers contains many common vendor drivers included for redirect/print compatibility.
- AppXRemoval: built-in list of Microsoft Store/UWP apps to remove from the image.
- Evergreen: definitions for automated app retrieval (7Zip, Chrome, Edge, Teams, OneDrive, Adobe, ZoomVDI, Java, FSLogix apps, deviceTRUST, Citrix, etc.) with selection Filters and optional post-extract scripts.
- Download: explicit URIs for extras (AutoHotKey, .NET Desktop Runtime 8, ReportViewer, SQL Native Client, VSTO, Teams bootstrapper, etc.).
- VCRedist: list of Visual C++ redistributors to collect and install.
- Copy: network source -> local destination copy operations (MasterBuild, Software).
- LocalPaths: local mount points used during the build (Drivers, OSOT, Scripts, Software).

OS Optimization Tool (OSOT)
- OSOT config referenced at: https://docs.omnissa.com/bundle/Optimizing-Images-for-Horizon/page/OptimizationParameters.html
- OSOT settings in this manifest reference a JSON "SCRMC_WIN11_20251211.json" and include many optimization toggles (visual effects, notifications, Windows Update disabled, Office Update disabled, remove Store apps, firewall/antivirus/securitycenter disabled, background set).
- The automation runs OSOT optimize and later generalize/finalize as part of the build flow.

Phases (high-level workflow)
- Phase 0 — Preparation & base installs
    - Copies files from network shares to C:\MasterBuild, downloads Evergreen/Download apps, installs drivers, initializes printer drivers.
    - Installs various VC redists, SQL native client, .NET Desktop Runtime, Edge, WebView2, OneDrive, Office (via ODT config), VSTO, ReportViewer.
    - Sets many registry policies (Windows Update targeting 24H2, Chrome RendererCodeIntegrity disabled, Teams WVD flags, Appx policies, RTAV webcam limits).
    - Post actions: restart Windows Update service, Update-Help, run Windows Update, optional pause, Restart-Computer.

- Phase 1 — Horizon agent & DEM, OSOT optimize + generalize
    - Pre-scripts ensure OS is up-to-date, pending reboots handled.
    - Installs VMware Horizon Agent and VMware DEM (Omnissa packages).
    - Disables Edge update services and prevents Edge elevation service; runs OSOT optimize and then generalize; runs SysPrep and reboots (automated watch).
    - State is persisted and Phase increments through registry state.

- Phase 2 — Common application installs
    - Installs end-user and infrastructure software (Teams, Edge provisioning, Chrome, Citrix Workspace, ZoomVDI, drivers, TSPrint/TSScan, many vendor apps).
    - Applies group registry policies to disable Google auto-updates.
    - Post: disables Google scheduled tasks/services, increments phase, restart.

- Phase 3 — Specialty clinical/business apps & drivers
    - Ensures time sync to domain, installs clinical apps (various hospital/medical packages), ScreenConnect client fixes, printer-related installs, sets svdriver AllowInstallerModification registry flag.
    - Post: increment phase and reboot.

- Phase 4 — Final application installs & cleanup
    - Provides pause for manual changes; installs remaining specialty apps (Epic Satellite, LabRetriever, Philips, Sleepware, XM Fax).
    - Epic installation has an interactive automation step (sends keys to installer).
    - Post: removes public desktop shortcuts, deletes MasterBuild software/drivers copies, runs OSOT Finalize All, optional pause, then Stop-Computer (shutdown).

State & orchestration
- The script relies on $Environment and $State objects, and persists the $State back to an environment variable path ($EnvironmentVariables). Phase progression is managed by incrementing $State.Phase and reboots.
- Several steps contain conditional pauses (If $State.Pause) requiring operator input.

Important registry changes (high-impact)
- Windows Update: disabled auto-updates, TargetReleaseVersionInfo set to "24H2".
- Chrome: RendererCodeIntegrityEnabled = 0 (required for some virtualization drivers).
- Teams: IsWVDEnvironment = 1; WebRTC/RTAV policies set for webcam handling.
- Appx: AllowAllTrustedApps = 1 and MdmHosts pattern configured.
- Google update policies set to disable auto-update checks.

Placeholders and actions required from customer
- Provide values for blank DC sub-keys: ConnectionServers, AppVol Manager1/2, NVIDIALicensingServer, FSLogixPaths.
- Verify network paths in "Copy" sections (\\\\srvfileshare\\...); ensure the build account has read access.
- Validate URIs and allowed external downloads (security policy).
- Confirm the OSOT JSON ("SCRMC_WIN11_20251211.json") and that OSOT binary exists at the local OSOTPath.
- Confirm any keys/secrets referenced (Epic key file) are available in expected locations.

Testing & deployment recommendations
- Run in an isolated lab VM first to validate:
    - File share access, download URIs, installer switches, reboots, and OSOT behavior.
    - Interactive sequences (Epic Satellite key entry automation).
    - Printer/driver initialization and print redirection behavior.
- Audit produced image for removed components (AppXRemoval list) and registry policy side effects (Windows Update and update ring).
- Keep a copy of the manifest and a changelog for future image rebuilds.

Files and paths used during build
- Local working tree: C:\MasterBuild
- OSOT executable expected in: C:\MasterBuild\OSOT (or [OSOTPath])
- Software repository: C:\MasterBuild\Software (or [SoftwarePath])
- Scripts: C:\MasterBuild\Scripts (or [ScriptPath])

Contact items for Converge / Customer
- Provide missing domain/Horizon integration values.
- Confirm desired Windows Update policy (TargetReleaseVersionInfo).
- Confirm list of approved printers and whether full PrinterDrivers list is required.
- Request permission to test external downloads and firewall egress for build servers.

Summary
- This manifest automates a complete master-image build: driver preparation, core runtimes, enterprise apps, Horizon agent, OS optimization, generalize/Sysprep, and cleanup. It is modular (Evergreen + Download lists) and phase-driven with operator-pauses available. Complete the blank entries, validate access to file shares/URIs, and run a staged lab test before production imaging.

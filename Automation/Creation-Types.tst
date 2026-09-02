Add-Type -ReferencedAssemblies System.Management.Automation -TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Management.Automation;

public class ApplicationTemplate
{
    public string Name { get; set; }
    public SourceDefinition Source { get; set; }
    public InstallDefinition[] Install { get; set; }
    public RegistryDefinition[] Registry { get; set; }
    public DetectionDefinition Detection { get; set; }
}

public class SourceDefinition
{
    public ScriptBlock[] PreScriptBlocks { get; set; }
    public CopyDefinition[] Copy { get; set; }
    public DownloadDefinition[] Download { get; set; }
    public EvergreenDefinition[] Evergreen { get; set; }
    public bool Manual { get; set; }
    public WinGetDefinition[] WinGet { get; set; }
    public ScriptBlock[] PostScriptBlocks { get; set; }
}

public class CopyDefinition
{
    public ScriptBlock[] PreScriptBlocks { get; set; }
    public string Source { get; set; }
    public ScriptBlock[] PostScriptBlocks { get; set; }
}

public class DownloadDefinition
{
    public ScriptBlock[] PreScriptBlocks { get; set; }
    public string FileName { get; set; }
    public string URI { get; set; }
    public ScriptBlock[] PostScriptBlocks { get; set; }
}

public class EvergreenDefinition
{
    public ScriptBlock[] PreScriptBlocks { get; set; }
    public string Name { get; set; }
    public string Filter { get; set; }
    public ScriptBlock[] PostScriptBlocks { get; set; }
}

public class WinGetDefinition
{
    public ScriptBlock[] PreScriptBlocks { get; set; }
    public string Name { get; set; }
    public ScriptBlock[] PostScriptBlocks { get; set; }
}

public class InstallDefinition
{
    public ScriptBlock[] PreScriptBlocks { get; set; }
    public string Path { get; set; }
    public string Arguments { get; set; }
    public bool Recurse { get; set; }
    public ScriptBlock[] PostScriptBlocks { get; set; }
}

public class RegistryDefinition
{
    public ScriptBlock[] PreScriptBlocks { get; set; }
    public string Path { get; set; }
    public string Name { get; set; }
    public string Value { get; set; }
    public string Type { get; set; }
    public ScriptBlock[] PostScriptBlocks { get; set; }
}

public class DetectionDefinition
{
    public string[] DisplayName { get; set; }
    public DetectionRegistryDefinition[] RegKey { get; set; }
    public string[] File { get; set; }
}

public class DetectionRegistryDefinition
{
    public string Path { get; set; }
    public string Property { get; set; }
    public string Value { get; set; }
}
"@
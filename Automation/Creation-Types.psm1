Add-Type -ReferencedAssemblies System.Management.Automation `
-TypeDefinition @"
using System;
using System.Collections.Generic;
using System.Management.Automation;

public class ApplicationTemplate
{
    public string Name { get; set; }

    public SourceDefinition Source { get; set; }
    public List<InstallDefinition> Install { get; set; }
    public List<RegistryDefinition> Registry { get; set; }
    public DetectionDefinition Detection { get; set; }

    public ApplicationTemplate()
    {
        Source = new SourceDefinition();
        Install = new List<InstallDefinition>();
        Registry = new List<RegistryDefinition>();
        Detection = new DetectionDefinition();
    }

    public ApplicationTemplate(string name) : this()
    {
        Name = name;
    }
}

public abstract class ScriptBlockContainer
{
    public List<ScriptBlock> PreScriptBlocks { get; set; }
    public List<ScriptBlock> PostScriptBlocks { get; set; }

    protected ScriptBlockContainer()
    {
        PreScriptBlocks = new List<ScriptBlock>();
        PostScriptBlocks = new List<ScriptBlock>();
    }
}

public class SourceDefinition : ScriptBlockContainer
{
    public List<CopyDefinition> Copy { get; set; }
    public List<DownloadDefinition> Download { get; set; }
    public List<EvergreenDefinition> Evergreen { get; set; }
    public List<WinGetDefinition> WinGet { get; set; }

    public bool Manual { get; set; }

    public SourceDefinition()
    {
        Copy = new List<CopyDefinition>();
        Download = new List<DownloadDefinition>();
        Evergreen = new List<EvergreenDefinition>();
        WinGet = new List<WinGetDefinition>();
    }
}

public class CopyDefinition : ScriptBlockContainer
{
    public string Source { get; set; }

    public CopyDefinition()
    {
    }

    public CopyDefinition(string source)
    {
        Source = source;
    }
}

public class DownloadDefinition : ScriptBlockContainer
{
    public string FileName { get; set; }
    public string URI { get; set; }

    public DownloadDefinition()
    {
    }

    public DownloadDefinition(string fileName, string uri)
    {
        FileName = fileName;
        URI = uri;
    }
}

public class EvergreenDefinition : ScriptBlockContainer
{
    public string Name { get; set; }
    public string Filter { get; set; }

    public EvergreenDefinition()
    {
    }

    public EvergreenDefinition(string name)
    {
        Name = name;
    }

    public EvergreenDefinition(string name, string filter)
    {
        Name = name;
        Filter = filter;
    }
}

public class WinGetDefinition : ScriptBlockContainer
{
    public string Name { get; set; }

    public WinGetDefinition()
    {
    }

    public WinGetDefinition(string name)
    {
        Name = name;
    }
}

public class InstallDefinition : ScriptBlockContainer
{
    public string Path { get; set; }
    public string Arguments { get; set; }
    public bool Recurse { get; set; }

    public InstallDefinition()
    {
        Recurse = true;
    }

    public InstallDefinition(string path, string arguments)
        : this()
    {
        Path = path;
        Arguments = arguments;
    }
}

public class RegistryDefinition : ScriptBlockContainer
{
    public string Path { get; set; }
    public string Name { get; set; }
    public string Value { get; set; }
    public string Type { get; set; }

    public RegistryDefinition()
    {
    }
}

public class DetectionDefinition
{
    public List<string> DisplayName { get; set; }
    public List<DetectionRegistryKey> RegKey { get; set; }
    public List<string> File { get; set; }

    public DetectionDefinition()
    {
        DisplayName = new List<string>();
        RegKey = new List<DetectionRegistryKey>();
        File = new List<string>();
    }
}

public class DetectionRegistryKey
{
    public string Path { get; set; }
    public string Property { get; set; }
    public string Value { get; set; }
}
"@
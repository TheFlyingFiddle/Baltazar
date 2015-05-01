module plugins;

public import bridge.plugins;
import std.file;

struct PluginConfig
{
	string[] pluginDlls;
}

import framework;
class PluginComponent : IApplicationComponent
{
	Plugins plugins;
	this(A)(ref A a, PluginConfig config)
	{
		createPlugins(a, plugins, config.pluginDlls);
	}

	void createPlugins(A)(ref A all, ref Plugins plugins, string[] paths)
	{
		plugins = Plugins(all, paths.length);
		foreach(path; paths)
		{
			plugins.loadLibrary(path);
		}
	}

	~this()
	{
		plugins.unloadAll();
	}

	override void initialize()
	{
		app.addService(&plugins);
	}

	float f = 0;
	override void step(Time time)
	{
		f += time.deltaSec;
		if(f > 2.0f)
		{
			f -= 2.0f;
			checkAndReloadPlugins(plugins);
		}
	}

	void checkAndReloadPlugins(Plugins plugins)
	{
		foreach_reverse(i; 0 .. plugins.fileChangedInfo.length)
		{
			//TODO change...
			//timeLastModified allocates data. This is just lol really :P
			if(plugins.fileChangedInfo[i] != timeLastModified(plugins.paths[i]))
			{
				if(exists(plugins.paths[i]))
					plugins.reloadLibrary(plugins.paths[i]);	
			}
		}
	}
}
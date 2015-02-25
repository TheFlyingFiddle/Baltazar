module plugins;

public import bridge.plugins;
import std.file;

struct PluginConfig
{
	string[] pluginDlls;
	string[] gameDlls;
}

import framework;
class PluginComponent : IApplicationComponent
{
	Plugins plugins;
	Plugins games;
	this(A)(ref A a, PluginConfig config)
	{
		createPlugins(a, plugins, config.pluginDlls);
		createPlugins(a, games,   config.gameDlls);
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
		app.addService(&games, "Games");
	}

	float f = 0;
	override void step(Time time)
	{
		f += time.deltaSec;
		if(f > 2.0f)
		{
			f -= 2.0f;
			checkAndReloadPlugins(plugins);
			checkAndReloadPlugins(games);
		}
	}

	void checkAndReloadPlugins(Plugins plugins)
	{
		foreach_reverse(i; 0 .. plugins.fileChangedInfo.length)
		{
			//TODO change...
			//timeLastModified allocates data.
			if(plugins.fileChangedInfo[i] != timeLastModified(plugins.paths[i]))
			{
				if(exists(plugins.paths[i]))
					plugins.reloadLibrary(plugins.paths[i]);	
			}
		}
	}
}
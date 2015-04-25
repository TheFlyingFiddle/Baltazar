
import concurency.task;
import window;
import rendering;
import content;
import allocation;
import external_libraries;
import log;
import std.c.string;
import std.path;

import framework.core;
import framework.components;
import framework.screen;

import ui;
import skin;
import std.process;

struct LauncherConfig
{
	WindowConfig	 window;
	ConcurencyConfig concurrency;
	RenderConfig	 render;
	ContentConfig	 content;
}

struct Baltazar
{
	string compileDirectory;
	string runtimeDirectory;
}

int main()
{
	init_dlls();
	scope(exit) shutdown_dlls();
	try
	{
		auto config = fromSDLFile!LauncherConfig(Mallocator.it, "config.sdl");
		run(config);
	}
	catch(Throwable t)
	{
		logErr("Crash!\n", t);
		while(t.next) 
		{
			t = t.next;
			logErr(t);
		}

		import std.stdio;
		readln;
	}

	return 0;
}

void run(LauncherConfig config) 
{
	RegionAllocator region = RegionAllocator(Mallocator.it.allocateRaw(1024 * 1024, 64));
	auto stack = ScopeStack(region);

	Application* app = stack.allocate!Application(stack, 20, 4, "Editor Launcher");

	auto loader	     = stack.allocate!AsyncContentLoader(stack, config.content);
	app.addService(loader);

	app.addComponent(stack.allocate!WindowComponent(config.window));
	app.addComponent(stack.allocate!TaskComponent(stack, config.concurrency));
	app.addComponent(stack.allocate!RenderComponent(stack, config.render));
	app.addComponent(stack.allocate!ScreenComponent(stack, 2));


	auto gui = loadGui(stack, app, "guiconfig.sdl");

	import screen.loading;
	auto mainScreen     = stack.allocate!(MainScreen)(gui);
	auto loadingScreen = stack.allocate!(LoadingScreen)(LoadingConfig(true, [], "Fonts"), mainScreen);

	auto s = app.locate!ScreenComponent;
	s.push(loadingScreen);

	import graphics;
	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);


	import std.datetime;
	app.run(TimeStep.fixed, 33_333.usecs);
}


class MainScreen : Screen
{
	Gui gui;
	this(Gui gui) 
	{ 
		super(true, true); 
		this.gui = gui;
	}

	override void initialize()
	{
	}

	override void deinitialize()
	{
	}

	override void update(Time time) 
	{
		import dialogs;
		auto window = app.locate!Window;
		gui.begin();

		//gui.toolbar(tb, selected, panels.map!(x => toTabPage(&x)));
		
		Rect create = Rect(20, window.size.y / 2 - 30, window.size.x / 2 - 40, 60);
		Rect open   = Rect(create.right + 40, window.size.y / 2 - 30, window.size.x / 2 - 40, 60);
		
		if(gui.button(create, "CREATE"))
		{
			char[256] buffer;
			if(openFileDialog("Project\0*.NEW_PROJECT\0", buffer[], false))
			{
				auto len = strlen(buffer.ptr);
				auto p   = buffer[0 .. len];

				makeDir(p);
				makeDir(p.buildPath("resources"));
				makeDir(p.buildPath("resources").buildPath("desktop"));
				makeDir(p.buildPath("runtime_resources"));


				auto rootPath = p.buildPath(p.baseName ~ ".baltz");
				Baltazar b = Baltazar("resources", "runtime_resources");
				toSDLFile(b, rootPath); 

				import std.file;
				if(exists("..\\SideScrollEditor\\Debug\\SideScrollEditor.exe"))
				{
					auto cmd = ["..\\SideScrollEditor\\Debug\\SideScrollEditor.exe", rootPath];
					spawnProcess(cmd, null , Config.none, "..\\SideScrollEditor\\");
				}

				app.stop();
			}
		}

		if(gui.button(open, "OPEN"))
		{
			char[256] buffer;
			if(openFileDialog("Project\0*.baltz\0", buffer[], true))
			{
				auto len		= strlen(buffer.ptr);
				auto rootPath   = buffer[0 .. len];

				auto cmd = ["..\\SideScrollEditor\\Debug\\SideScrollEditor.exe", rootPath];
				spawnProcess(cmd, null , Config.none, "..\\SideScrollEditor\\");

				app.stop();
			}
		}


		gui.end();
	}
}

void makeDir(const(char)[] dir)
{
	import std.file;
	if(!exists(dir))
		mkdir(dir);
}
module main;

import rendering;
import content;
import graphics, math, collections;
import allocation;

import concurency.task;
import content.sdl;
import content.reloading;
import mainscreen;
import framework;
import window.window;
import window.keyboard;

import external_libraries;
import log;

import plugins;
import std.process;

struct Baltazar
{
	string compileDirectory;
	string runtimeDirectory;
}

Pid contentPid;

int main(string[] args)
{
	string project = "..\\TestGame\\TestGame.baltz";
	if(args.length > 1) project = args[1];

	import core.memory;
	initializeScratchSpace(1024 * 1024);

	init_dlls();
	scope(exit) shutdown_dlls();
	try
	{
		auto config  = fromSDLFile!DesktopAppConfig(Mallocator.it, "config.sdl");
		run(config, project);
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

void run(DesktopAppConfig config, string projectPath) 
{
	RegionAllocator region = RegionAllocator(Mallocator.it.allocateRaw(1024 * 1024 * 50, 64));
	auto stack = ScopeStack(region);
	auto app = createDesktopApp(stack, config);

	import std.path;
	auto balt = fromSDLFile!Baltazar(Mallocator.it, projectPath);
	auto root = projectPath.dirName;
	import std.process;
	char[][] commands;
	commands ~= cast(char[])"..\\Content_Pipeline\\Debug\\Content_pipeline.exe";
	commands ~= cast(char[])root.buildPath(balt.compileDirectory);
	commands ~= cast(char[])root.buildPath(balt.runtimeDirectory);
	contentPid = spawnProcess(commands);

	auto gameAssetsLoader = stack.allocate!AsyncContentLoader(stack, ContentConfig(512, buildPath(root, balt.runtimeDirectory).buildPath("desktop")));
	app.addService(gameAssetsLoader, "game");
	app.addComponent(stack.allocate!ReloadingComponent(ReloadingConfig(21345, "game")));
						 

	import screen.loading;
	auto endScreen     = stack.allocate!(MainScreen)(null);
	
	//The preloading!
	auto loadingScreen = stack.allocate!(LoadingScreen)(LoadingConfig(true, [], "Fonts"), endScreen);
	
	auto s = app.locate!ScreenComponent;
	s.push(loadingScreen);

	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

	try
	{
		import std.datetime;
		app.run(TimeStep.fixed, 16_666.usecs);

		kill(contentPid);
		wait(contentPid);
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

}
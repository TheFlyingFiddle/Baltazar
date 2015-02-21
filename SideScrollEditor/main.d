module main;

import rendering;
import content;
import graphics, math, collections;
import allocation;

import concurency.task;
import content.sdl;
import content.reloading;
import mainscreen;
import gameplayscreen;
import framework;
import window.window;
import window.keyboard;

import external_libraries;
import log;

import core.sys.windows.windows;
import core.runtime;
import plugins;

void main()
{
	import core.memory;
	GC.disable();

	//import std.process;
	//char[][] commands;
	//commands ~= cast(char[])"..\\Content_Pipeline\\Debug\\Content_pipeline.exe";
	//commands ~= cast(char[])"..\\resources";
	//commands ~= cast(char[])"..\\compiled_resources";
	//spawnProcess(commands);

	initializeScratchSpace(Mallocator.it, 1024 * 1024);

	init_dlls();
	scope(exit) shutdown_dlls();
	try
	{
		auto config = fromSDLFile!DesktopAppConfig(Mallocator.it, "config.sdl");
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

	import std.stdio;
	readln;
}

void run(DesktopAppConfig config) 
{
	RegionAllocator region = RegionAllocator(new ubyte[1024 * 1024 * 5]);
	auto stack = ScopeStack(region);
	auto app = createDesktopApp(stack, config);

	import screen.loading;
	auto gameplay	   = stack.allocate!(GameplayScreen)();
	auto endScreen     = stack.allocate!(MainScreen)(gameplay);
	
	//The preloading!
	auto loadingScreen = stack.allocate!(LoadingScreen)(LoadingConfig(true, [], "Fonts"), endScreen);
	
	auto s = app.locate!ScreenComponent;
	s.push(loadingScreen);

	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

	try
	{
		app.run();
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
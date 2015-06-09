module main;

import rendering;
import content;
import graphics, math, collections;
import allocation;

import concurency.task;
import content.sdl;
import content.reloading;
import framework;
import window.window;
import window.keyboard;
import gameplay;
import external_libraries;
import log;

int main(string[] args)
{
	import core.memory;
	GC.disable();
	initializeScratchSpace(1024 * 1024);

	init_dlls();
	scope(exit) shutdown_dlls();
	try
	{
		auto config  = fromSDLFile!DesktopAppConfig(Mallocator.it, "config.sdl");
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

void run(DesktopAppConfig config) 
{
	RegionAllocator region = RegionAllocator(Mallocator.it.allocateRaw(1024 * 1024 * 50, 64));
	auto stack = ScopeStack(region);
	auto app = createDesktopApp(stack, config);

	import screen.loading;
	auto gamplayScreen = stack.allocate!(MainScreen);
	//auto loadingScreen = stack.allocate!(LoadingScreen)(LoadingConfig(true, [], "Fonts"), gamplayScreen);
	auto s = app.locate!ScreenComponent;
	s.push(gamplayScreen);

	gl.enable(Capability.blend);
	gl.BlendFunc(BlendFactor.srcAlpha, BlendFactor.oneMinusSourceAlpha);

	import std.datetime;
	app.run(TimeStep.fixed, 16_666.usecs);
}
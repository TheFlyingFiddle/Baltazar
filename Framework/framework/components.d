module framework.components;

import framework;
import concurency.task;
import network.server;
import network.router; 
import network.service;
import window.window;
import window.keyboard;
import window.mouse;
import window.clipboard;
import window.gamepad;

import log;
final class WindowComponent : IApplicationComponent
{

	private Window _window;
	private Keyboard _keyboard;
	private Mouse _mouse;
	private GamePad _gamePad;

	private Clipboard _clipboard;

	this(WindowConfig config)
	{
		_window    = WindowManager.create(config);
		_mouse	   = Mouse(&_window);
		_keyboard  = Keyboard.create(&_window);
		_gamePad   = GamePad.init;
		_clipboard = Clipboard(&_window);
	}

	~this()
	{
		_window.obliterate();
		_gamePad.disable();
	}

	override void initialize()
	{
		app.addService(&_window);
		app.addService(&_keyboard);
		app.addService(&_mouse);
		app.addService(&_clipboard);
		app.addService(&_gamePad);

		_gamePad.enable();
	}

	override void step(Time time)
	{
		_window.update();
		if(_window.shouldClose)
			app.stop();

		_mouse.update();
		_keyboard.update();
		_gamePad.update();
	}

	override void postStep(Time time)
	{
		_mouse.postUpdate();
		_keyboard.postUpdate();
		_window.swapBuffer(); 
	}
}

class TaskComponent : IApplicationComponent
{
	this(A)(ref A al, ConcurencyConfig config)
	{
		concurency.task.initialize(al, config);	
	}

	override void step(Time time)
	{
		import concurency.task;
		consumeTasks();
	}
}

class NetworkComponent : IApplicationComponent
{
	Server* server;
	Router* router;
	NetworkServices* provider;

	private string resourceDir;

	this(A)(ref A al, ServerConfig config, string resourceDir)
	{
		import allocation;
		server   = al.allocate!Server(al, config);
		router   = al.allocate!Router(al, server);
		provider = al.allocate!NetworkServices(al, servicePort, 100);


		struct ServerServiceData
		{
			char[] gameName;
			uint ip;
			ushort tcpPort, udpPort;
			ushort contentPort;
		}
		
		//This should be all that is nessecary to provide the information for the broadcast.
		ServerServiceData data;
		data.gameName = cast(char[])"tower_defence"; //This line is wrong!
		data.ip = server.listenerAddress.addr;
		data.tcpPort = server.listenerAddress.port;
		data.udpPort = server.updAddress.port;
		data.contentPort = 13462; //BAD BAD BAD

		provider.add("SERVER_DISCOVERY_SERVICE", data);
		this.resourceDir = resourceDir;
	}

	override void initialize()
	{
		import network.file;
		app.addService(server);
		app.addService(router);
		app.addService(provider);

		auto ip = server.listenerAddress.addr;
		taskpool.doTask!(listenForFileRequests)(ip, cast(ushort)13462, resourceDir);
	}

	override void step(Time time)
	{
		server.update(time.delta.to!("seconds", float));
		provider.poll();
	}
}

class RenderComponent : IApplicationComponent
{
	import rendering.renderer, rendering.combined;
	import graphics.color;

	Renderer2D* renderer;
	Color		clear;
	this(A)(ref A al, RenderConfig config)
	{
		renderer = al.allocate!Renderer2D(al, config);
		clear    = config.clearColor;
	}

	override void initialize()
	{
		app.addService(renderer);
	}

	override void preStep(Time time)
	{
		import math.vector;

		auto w = app.locate!Window;
		renderer.viewport = float2(w.size);

		import graphics;
		gl.viewport(0,0, cast(uint)w.size.x, cast(uint)w.size.y);
		gl.clearColor(clear.r, clear.g, clear.b, clear.a);
		gl.clear(ClearFlags.color);
	}
}

class SoundComponent : IApplicationComponent
{
	import sound.player;
	SoundPlayer player;

	this(A)(ref A all, SoundConfig config)
	{
		player = SoundPlayer(all, config);
	}

	override void initialize()
	{
		app.addService(&player);
	}

}
version(RELOADING)
{
	import content, allocation;
	struct ReloadingConfig
	{
		ushort port;
		@Optional("") string loader;
	}


	class ReloadingComponent : IApplicationComponent
	{
		ushort port;
		string theLoader;
		NetworkServiceFinder finder;
		bool found;

		this(ReloadingConfig config)
		{
			this.port		= config.port;
			this.theLoader	= config.loader;
			this.found		= false;

			finder = NetworkServiceFinder(Mallocator.it, 23451, "FILE_RELOADING_SERVICE", &onServiceFound);
		}

		override void initialize()
		{
		}

		void onServiceFound(const(char)[] service, ubyte[] serviceInfo)
		{
			import log;
			logInfo("Found Service!");

			import util.bitmanip;
			this.found = true;

			auto ip		= serviceInfo.read!uint;
			auto port	= serviceInfo.read!ushort;

			import content.content, content.reloading;
			auto loader = app.locate!AsyncContentLoader(theLoader);
			setupReloader(ip, port, loader);
		}

		override void step(Time time)
		{
			if(!found)
			{
				if(!finder.pollServiceFound())
					finder.sendServiceQuery();
			}
		}
	}
}
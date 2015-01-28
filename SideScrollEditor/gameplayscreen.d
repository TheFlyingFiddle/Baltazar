module gameplayscreen;

import framework;
import common.systems;
import common.bindings;
import state;
import allocation;

class GameplayScreen : Screen
{
	World w;
	this() 
	{ 
		super(true, true); 
	}

	override void initialize()
	{
		w = World(Mallocator.cit, 20, 20, 1024, app);
		w.addSystem!SpriteSystem(1000, 1);
		w.addSystem!Box2DPhys(1000, 3);
		w.addSystem!Box2DRender(1000, 5);
		w.addInitializer!Box2DInitializer();
		w.initialize();

		auto savePath = app.locate!(SavePath);

		import std.c.string;
		auto len = strlen(savePath.path.ptr);

		//Fix this later!!!
		import content.sdl;
		auto c = fromSDLFile!(EditorStateContent)(Mallocator.it, cast(string)savePath.path[0 .. len], CompContext());
		foreach(ref item; c.items)
		{
			EntityArchetype arch;
			arch.groups = 0;
			arch.name   = "";
			arch.components = cast(Component[])item.components.array;

			auto entity = w.entities.create(arch);
			w.addEntity(*entity);
		}
	}

	override void deinitialize()
	{
		w.deinitialize();
	}

	override void update( Time time) 
	{
		w.step(time);

		import window.keyboard;

		auto kb = app.locate!Keyboard;
		if(kb.wasPressed(Key.escape))
		{
			owner.pop();
		}
	}
}
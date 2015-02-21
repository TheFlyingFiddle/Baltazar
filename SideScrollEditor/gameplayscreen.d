module gameplayscreen;

import framework;
import allocation;

import bridge;
import collections.list;
import util.variant;
import reflection;

//import log;
void logInfo(T...)(T t) { }


class GameplayScreen : Screen
{
	Plugins* plugin;
	World w;
	List!EntityArchetype archetypes;

	this() 
	{ 
		super(true, true); 
	}

	override void initialize()
	{
		plugin = app.locate!(Plugins)("Games");
		plugin.preReload  = &pluginPreReload;
		plugin.postReload = &pluginPostReload;

		archetypes = List!EntityArchetype(Mallocator.it, 100);
		app.addService(&archetypes);

		initializeWorld();
		loadWorld();
	}

	override void deinitialize()
	{
		deinitializeWorld();
		app.removeService!(List!EntityArchetype);
	}

	void initializeWorld()
	{
		w = World(Mallocator.cit, 20, 20, 1024, app);
		foreach(type; plugin.attributeTypes!EntitySystem)
		{
			auto es = type.getAttribute!EntitySystem;
			w.addSystem!(ReflectedSystem)(1000, es.order, cast(const(MetaType)*)&type);
		}

		foreach(type; plugin.attributeTypes!EntityInitializer)
		{
			auto es = type.getAttribute!EntityInitializer;
			w.addInitializer!(ReflectedInitializer)(es.order, cast(const(MetaType)*)&type);
		}

		w.initialize();
	}

	void loadWorld()
	{		
		import content.sdl;
		import reflection.serialization;
		import std.c.string;

		//Only thing that needs to change is that 
		//Loadworld needs to be changed to use
		//New loading system!

		/*
		auto savePath = app.locate!SavePath;
		auto len = strlen(savePath.path.ptr);

		auto p = app.locate!Plugins;
		auto context = ReflectionContext(p.assemblies.array);
		auto c = fromSDLFile!(EditorStateContent)(Mallocator.it, cast(string)savePath.path[0 .. len], context);

		foreach(ref a; c.archetypes)
		{
			EntityArchetype arch;
			arch.groups = 0;
			arch.name   = a.name;
			arch.components = cast(Component[])a.components.array;
			archetypes ~= arch;
		}

		foreach(ref item; c.items)
		{
			EntityArchetype arch;
			arch.groups = 0;
			arch.name   = "";
			arch.components = cast(Component[])item.components.array;

			auto entity = w.entities.create(arch);
			entity.uniqueID = item.id;
			w.addEntity(*entity);
		}
		*/
	}

	void deinitializeWorld()
	{
		w.deinitialize();
	}

	void pluginPreReload(Plugin plugin)
	{
		import content.sdl;
		import reflection.serialization;
		deinitializeWorld();
	}

	void pluginPostReload(Plugin plugin)
	{
		initializeWorld();
		loadWorld();
	}

	override void update(Time time) 
	{
		import rendering.combined;
		auto renderer = app.locate!Renderer2D;
		renderer.begin();
		w.step(time);
		renderer.end();


		import window.keyboard;
		auto kb = app.locate!Keyboard;
		if(kb.wasPressed(Key.escape))
		{
			owner.pop();
		}
	}
}

final class ReflectedSystem : System
{
	string name;

	alias step_t = void delegate(Time, List!(Entity), World*);
	alias init_t = void delegate(IAllocator, World*);
	alias sadd_t = bool delegate(ref Entity entity);
	alias erem_t = void delegate(ref Entity entity);

	VariantN!64 system;
	Binding!step_t preS, postS, curS;
	Binding!init_t preI, curI, deI;
	Binding!sadd_t sadd;
	Binding!erem_t erem;

	this(const(MetaType)* systemType)
	{
		name = systemType.typeInfo.name;
		system = systemType.initial!64;

		preS  = systemType.tryBind!(step_t)(system, "preStep");
		postS = systemType.tryBind!(step_t)(system, "postStep");
		curS  = systemType.tryBind!(step_t)(system, "step");

		preI  = systemType.tryBind!(init_t)(system, "preInitialize");
		curI  = systemType.tryBind!(init_t)(system, "initialize");
		deI   = systemType.tryBind!(init_t)(system, "deinitialize");

		erem  = systemType.tryBind!(erem_t)(system, "entityRemoved");
		sadd  = systemType.tryBind!(sadd_t)(system, "shouldAddEntity");
	}

	override void preStep(Time time) 
	{
		if(preS) preS(time, entities, world);	
	}
	
	override void postStep(Time time) 
	{		
		if(postS) postS(time, entities, world);	
	}

	override void step(Time time)	 
	{		
		if(curS) curS(time, entities, world);	
	}

	override void preInitialize(IAllocator all) 
	{
		if(preI) preI(all, world);	
	}

	override void initialize(IAllocator all)
	{
		if(curI) curI(all, world);
	}

	override void deinitialize(IAllocator all) 
	{
		if(deI) deI(all, world);
	}

	override void entityRemoved(ref Entity entity)
	{
		if(erem) erem(entity);
	}

	override bool shouldAddEntity(ref Entity entity)
	{
		if(sadd)  return sadd(entity);
		return false;
	}
}

final class ReflectedInitializer : Initializer
{
	alias init_t  = void delegate(IAllocator, World*);
	alias efun_t  = bool delegate(ref Entity entity);
	alias einit_t = void delegate(ref Entity entity);

	string name;
	VariantN!64 initializer;
	Binding!init_t  curI, deI;
	Binding!efun_t eadd;
	Binding!einit_t einit;

	this(const(MetaType)* systemType)
	{
		name = systemType.typeInfo.name;

		initializer = systemType.initial!64;
		curI   = systemType.tryBind!(init_t)(initializer, "initialize");
		deI    = systemType.tryBind!(init_t)(initializer, "deinitialize");
		eadd   = systemType.tryBind!(efun_t)(initializer, "shouldInitializeEntity");
		einit  = systemType.tryBind!(einit_t)(initializer, "initializeEntity");
	}

	override void initialize(IAllocator all)
	{		
		if(curI) 
		{
			logInfo(name, " initialize");
			curI(all, world);	
			logInfo(name, " initialize Exit");	
		}
	}

	override void deinitialize(IAllocator all) 
	{
		if(deI) 
		{
			logInfo(name, " deinitialize");
			deI(all, world);	
			logInfo(name, " deinitialize Exit");	
		}
	}

	override bool shouldInitializeEntity(ref Entity entity)
	{
		if(eadd) 
		{
			logInfo(name, " shouldAddEntity");
			auto res = eadd(entity);
			logInfo(name, "res shouldAddEntity Exit");

			return res;
		}
		return false;
	}

	override void initializeEntity(ref Entity entity)
	{
		if(einit)
		{
			logInfo(name, " initializeEntity");
			einit(entity);
			logInfo(name, "initializeEntity Exit");
		}
	}
}
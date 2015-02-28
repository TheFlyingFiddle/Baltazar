module plugin.core.data;

import allocation;
import bridge.attributes;
import collections.list;
import util.variant;
import math.vector;
import reflection;

@Data
struct WorldData
{
	WorldItemID selected;
	GrowingList!WorldItem items;
	GrowingList!WorldItem archetypes;

	int selectedItem;
	int selectedArchetype;


	@property WorldItem* item()
	{
		return selectedItem < items.length ? &items[selectedItem] : null;
	}

	@property WorldItem* archetype()
	{
		return selectedArchetype < archetypes.length ? &archetypes[selectedArchetype] : null;
	}


	void select(uint index, ubyte type)
	{
		selected.index = cast(ushort)index;
		selected.type  = type;
	}

	this(IAllocator allocator)
	{
		items	   = GrowingList!WorldItem(allocator, 100);
		archetypes = GrowingList!WorldItem(allocator, 5);
	}

	void deallocate(IAllocator allocator)
	{
		items.deallocate();
		archetypes.deallocate();
	}
}

alias StateComponent = VariantN!48;
struct WorldItem
{
	GrowingList!StateComponent components;
	string name;
	uint   id;

	this(string name)
	{
		this.name		= name;
		this.components = GrowingList!(StateComponent)(Mallocator.cit, 4);

		import std.random;
		id = uniform(0, uint.max);
	}

	void deallocate()
	{
		components.deallocate();
	}

	WorldItem clone()
	{
		WorldItem item = WorldItem(this.name);
		foreach(ref cmp; this.components)
			item.components ~= cmp;

		return item;
	}

	T* get(T)()
	{
		auto p = peek!T;
		if(p) return p;

		assert(0, "Component not found found! " ~ T.stringof);
	}

	T* peek(T)()
	{
		foreach(ref c; components)
		{
			auto p = c.peek!T;
			if(p)
				return p;
		}

		return null;
	}

	StateComponent* peekComponent(const(RTTI)* type)
	{
		foreach(ref c; components)
		{
			if(type.isTypeOf(c))
			{
				return &c;
			}
		}

		return null;
	}

	import reflection;
	bool hasComponent(const(RTTI)* type)
	{	
		foreach(ref c; components)
		{
			if(type.isTypeOf(c))
			{
				return true;
			}
		}

		return false;
	}
}

struct WorldItemID
{
	ushort index;
	ubyte  type;

	GrowingList!WorldItem* owner()
	{
		import bridge.core;
		auto wdata = Editor.data.locate!(WorldData);
		if(type == 0)
			return &wdata.items;
		else 
			return &wdata.archetypes;
	}

	WorldItem* proxy()
	{
		import bridge.core;
		auto wdata = Editor.data.locate!(WorldData);
		if(type == 0)
			return index < wdata.items.length ? &wdata.items[index] : null;
		else 
			return index < wdata.archetypes.length ? &wdata.archetypes[index] : null;
	}
}

@Data
struct DoUndo
{
	template isCommand(U)
	{
		enum isCommand = is(U == struct) &&
			__traits(compiles, 
					 {
						 U u;
						 u.apply();
						 u.revert();
					 });
	}

	alias Command = VariantN!(64);

	uint redoCount;
	GrowingList!Command commands;

	this(IAllocator allocator)
	{
		redoCount  = 0;
		commands   = GrowingList!(Command)(allocator, 100);
	}

	bool canRedo()
	{
		return redoCount > 0;
	}

	void add(U)(auto ref U u) if(isCommand!U)
	{
		if(redoCount > 0)
		{
			foreach(i; commands.length - redoCount .. commands.length)
				call!"clear"(commands[i]);

			commands.length = commands.length - redoCount;
			redoCount = 0;
		}

		commands ~= Command(u);
	}

	void apply(U)(auto ref U u) if(isCommand!U)
	{
		add!(U)(u);
		call!"apply"(commands[$ - 1]);
	}

	void undo()
	{
		if(commands.length > redoCount)
		{
			call!"revert"(commands[$ - redoCount - 1]);
			redoCount++;
		}
	}

	void redo()
	{
		if(redoCount > 0)
		{
			call!"apply"(commands[$ - redoCount]);
			redoCount--;
		}
	}

	void clear()
	{
		foreach(ref cmd; commands)
			call!"clear"(cmd);

		commands.clear();
		redoCount = 0;
	}

	auto call(string method)(ref Command command)
	{
		import bridge.core, bridge.plugins;
		auto p		= Editor.services.locate!(Plugins);
		auto type	= p.findType(command.id);
		alias D = void delegate();

		auto d = type.tryBind!(D)(command, method);
		if(d)
		{
			d();
		}
	}
}


struct Camera
{
	float4 viewport = float4.zero;
	float2 position = float2.zero;
	float  scale    = 0;


	float2 screenToWorld(float2 screenPos)
	{
		screenPos = (screenPos + position * scale) - viewport.xy;
		return screenPos / scale;
	}

	float2 worldToScreen(float2 world)
	{
		world = (world - position) * scale;
		return world + viewport.xy;
	}
}



import reflection.generation;
enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.core.data);
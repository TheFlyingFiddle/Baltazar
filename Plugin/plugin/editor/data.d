module plugin.editor.data;

import allocation;
import bridge.attributes;
import collections.list;
import util.variant;

@Data
struct WorldData
{
	WorldItemID selected_;
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
		selected_.index = cast(ushort)index;
		selected_.type  = type;
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

	WorldItem* proxy()
	{
		import bridge.core;
		auto wdata = Editor.data.locate!(WorldData);
		if(type == 0)
			return index < wdata.items.length ? &wdata.items[index] : null;
		else 
			return index < wdata.items.length ? &wdata.archetypes[index] : null;
	}
}
module plugin.editor.data;

import allocation;
import bridge.attributes;
import collections.list;
import util.variant;

@Data
struct WorldData
{
	GrowingList!WorldItem items;
	GrowingList!WorldItem archetypes;

	WorldItem* selected_;

	@property WorldItem* selected()
	{
		return selected_;
	}

	@property void selected(WorldItem* item)
	{
		selected_ = item;
	}

	this(IAllocator allocator)
	{
		items	   = GrowingList!WorldItem(allocator, 100);
		archetypes = GrowingList!WorldItem(allocator, 5);
		selected_  = null;
	}

	void deallocate(IAllocator allocator)
	{
		foreach(ref item; items)
			item.deallocate();
		items.deallocate();
	}
}

alias StateComponent = VariantN!48;
struct WorldItem
{
	List!StateComponent components;
	string name;
	uint   id;

	this(string name)
	{
		this.name = name;
		components = List!StateComponent(Mallocator.it, 20);

		import std.random;
		id = uniform(0, uint.max);
	}

	void deallocate()
	{
		components.deallocate(Mallocator.it);
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
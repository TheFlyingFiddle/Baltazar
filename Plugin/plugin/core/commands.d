module plugin.core.commands;

import bridge;
import allocation;
import plugin.core.data;
import collections.list;

struct AddItem
{
	uint archetype;
	uint index;

	this(int i)
	{
		auto d = Editor.data.locate!(WorldData);
		archetype = d.selectedArchetype;
	}

	void apply()
	{
		WorldItem item;
		auto d = Editor.data.locate!(WorldData);
		if(archetype < d.archetypes.length)
			item = d.archetypes[archetype].clone();
		else 
			item = WorldItem("Item");

		index	 = cast(uint)d.items.length;
		d.items ~= item;
	}

	void revert()
	{
		auto d = Editor.data.locate!(WorldData);
		d.items[index].deallocate();
		d.items.removeAt(index);
	}

}

struct AddArchetype
{
	uint index;
	this(int i) { }

	void apply()
	{
		auto d = Editor.data.locate!(WorldData);
		d.archetypes ~= WorldItem("Archetype");
		index = cast(uint)d.archetypes.length - 1;
	}

	void revert()
	{
		auto d = Editor.data.locate!(WorldData);
		d.archetypes[index].deallocate();
		d.archetypes.removeAt(index);
	}
}

struct ComponentChanged
{
	WorldItemID item;
	uint index;
	StateComponent component;

	this(size_t index, StateComponent component)
	{
		auto d	       = Editor.data.locate!(WorldData);
		item	       = d.selected;
		this.index	   = cast(uint)index;
		this.component = component; 
	}

	void apply()
	{
	    auto tmp = item.proxy.components[index];
		item.proxy.components[index] = component;
		this.component = tmp;
	}

	void revert()
	{
	    auto tmp = item.proxy.components[index];
		item.proxy.components[index] = component;
		this.component = tmp;
	}
}

align(4) struct RemoveItem
{
	WorldItem   item;
	WorldItemID id;

	this(int i)
	{
		auto d = Editor.data.locate!(WorldData);
		this.id = d.selected;
	}

	void apply()
	{
		item = *id.proxy;
		id.owner.removeAt(id.index);
	}

	void revert()
	{
		id.owner.insert(id.index, item);
	}
}

struct ChangeItemName
{
	WorldItemID item;
	string oldName;
	string newName;

	this(const(char[]) newName)
	{
		auto d = Editor.data.locate!(WorldData);
		this.item = d.selected;
		auto tmp =  Mallocator.it.allocate!(char[])(newName.length);	
		tmp[] = newName;
		this.newName = cast(string)tmp;
	}

	void apply()
	{
		oldName			 = item.proxy.name;
		item.proxy.name  = newName;
	}

	void revert()
	{
		item.proxy.name = oldName;
	}

	void clear()
	{
		Mallocator.it.deallocate(newName);
	}
}

struct AddComponent
{
	WorldItemID item;
	StateComponent component;

	this(StateComponent component)
	{
		auto d = Editor.data.locate!(WorldData);
		this.item	   = d.selected;
		this.component = component;
	}	

	void apply()
	{
		item.proxy.components ~= component;
	}

	void revert()
	{
		item.proxy.components.length--;
	}
}

struct RemoveComponent
{
	WorldItemID item;
	int componentIndex;
	StateComponent component;

	this(size_t componentIndex)
	{
		auto d = Editor.data.locate!(WorldData);
		this.item = d.selected;

		this.componentIndex = cast(int)componentIndex;
		this.component = item.proxy.components[componentIndex];
	}

	void apply()
	{
		item.proxy.components.removeAt(componentIndex);
	}

	void revert()
	{
		item.proxy.components.insert(componentIndex, component);
	}
}


import reflection.generation;
enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.core.commands);
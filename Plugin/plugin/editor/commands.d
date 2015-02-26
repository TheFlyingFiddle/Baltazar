module plugin.editor.commands;

import bridge;
import allocation;
import plugin.editor.data;
import collections.list;

struct AddItem
{
	uint archetype;
	uint index;

	this(int)
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

		index = d.items.length;
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
	this(int) { }

	void apply()
	{
		auto d = Editor.data.locate!(WorldData);
		d.archetypes ~= WorldItem("Archetype");
		index = d.archetypes.length - 1;
	}

	void revert()
	{
		auto d = Editor.data.locate!(WorldData);
		d.archetypes[index].deallocate();
		d.archetypes.removeAt(index);
	}
}

struct RemoveItem
{
	WorldItemID id;
	WorldItem   item;

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

	this(int componentIndex)
	{
		auto d = Editor.data.locate!(WorldData);
		this.item = d.selected;

		this.componentIndex = componentIndex;
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
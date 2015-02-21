module plugin.editor.commands;

import bridge;
import allocation;
import plugin.editor.data;
import collections.list;

struct ChangeItemName
{
	WorldItem* item;
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
		oldName    = item.name;
		item.name  = newName;
	}

	void revert()
	{
		item.name = oldName;
	}

	void clear()
	{
		Mallocator.it.deallocate(newName);
	}
}

struct AddComponent
{
	WorldItem* item;
	StateComponent component;

	this(StateComponent component)
	{
		auto d = Editor.data.locate!(WorldData);
		this.item = d.selected;
		this.component = component;
	}	

	void apply()
	{
		item.components ~= component;
	}

	void revert()
	{
		item.components.length--;
	}
}

struct RemoveComponent
{
	WorldItem* item;
	int componentIndex;
	StateComponent component;

	this(int componentIndex)
	{
		auto d = Editor.data.locate!(WorldData);
		this.item = d.selected;

		this.componentIndex = componentIndex;
		this.component = item.components[componentIndex];
	}

	void apply()
	{
		item.components.removeAt(componentIndex);
	}

	void revert()
	{
		item.components.insert(componentIndex, component);
	}
}
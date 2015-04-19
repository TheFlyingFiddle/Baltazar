module plugin.editor.panels.entity;
import plugin.editor.panels.common;


@EditorPanel("Entities", PanelPos.left)
struct EntityPanel
{
	GrowingList!uint selected;
	this(IAllocator all) 
	{
		selected = GrowingList!(uint)(all);
	}

	void show(PanelContext* context)
	{
		import std.stdio;
		auto gui		   = context.gui;
		auto state		   = Editor.state;

		Rect lp			   = context.area;
		Rect newItemBox    = Rect(lp.x, lp.y, lp.w / 2 - defSpacing, defFieldSize);
		Rect deleteItemBox = Rect(newItemBox.right + defSpacing * 2, lp.y, newItemBox.w, defFieldSize);
		Rect itemBox	   = Rect(lp.x, newItemBox.top + defSpacing, lp.w, lp.h - (newItemBox.top + defSpacing * 2 - lp.y));

		auto e = state.getProperty!(Guid[])(Guid.init, EntitySet);
		auto entities = e ? *e : Guid[].init;

		this.selected.clear();
		foreach(ref guid; SharedData.selected)
		{
			auto cnt = entities.countUntil!(x => x == guid);
			if(cnt != -1) this.selected ~= cast(uint)cnt;
		}

		(*gui).listbox(itemBox, selected, entities.map!(x => state.proxy!Entity(x).name));

		if((*gui).button(newItemBox, "New"))
		{
			auto archetypes = state.getProperty!(Guid[])(Guid.init, ArchetypeSet);
			if(archetypes)
			{
			 	auto idx = (*archetypes).countUntil!(x => x == SharedData.archetype);
				if(idx != -1)
				{
					auto obj    = state.object((*archetypes)[idx]);
					auto entity = state.createObject();
					state.addToSet(Guid.init, EntitySet, entity);
					foreach(k, v; obj)
						state.setPropertyTyped(entity, k, v);
					
					state.setRestorePoint();
				}
				else 
				{
					Entity.create(state, "Item", EntitySet);
					state.setRestorePoint();
				}
			}
			else 
			{
				Entity.create(state, "Item", EntitySet);
				state.setRestorePoint();
			}
		}

		if((*gui).button(deleteItemBox, "Delete") || 
		   gui.keyboard.wasPressed(Key.delete_))
		{
			import std.algorithm;
			selected.base_.sort!((a, b) => b < a);
			foreach(s; selected)
			{
				Entity.destroy(state, entities[s], EntitySet);
			}

			state.setRestorePoint();
			selected.clear();
		}

		SharedData.selected.clear();
		foreach(ref sel; selected)
		{
			SharedData.selected ~= entities[sel];
		}
	}
}

@EditorPanel("Archetypes", PanelPos.left)
struct ArchetypePanel
{
	GrowingList!uint selected;
	this(IAllocator all) 
	{
		selected = GrowingList!(uint)(all);
	}

	void show(PanelContext* context)
	{
		import std.stdio;
		auto gui		   = context.gui;
		auto state		   = Editor.state;

		Rect lp			   = context.area;
		Rect newItemBox    = Rect(lp.x, lp.y, lp.w / 2 - defSpacing, defFieldSize);
		Rect deleteItemBox = Rect(newItemBox.right + defSpacing * 2, lp.y, newItemBox.w, defFieldSize);
		Rect itemBox	   = Rect(lp.x, newItemBox.top + defSpacing, lp.w, lp.h - (newItemBox.top + defSpacing * 2 - lp.y));

		auto e = state.getProperty!(Guid[])(Guid.init, ArchetypeSet);
		auto entities = e ? *e : Guid[].init;

		this.selected.clear();
		foreach(ref guid; SharedData.selected)
		{
			auto cnt = entities.countUntil!(x => x == guid);
			if(cnt != -1) this.selected ~= cast(uint)cnt;
		}

		(*gui).listbox(itemBox, selected, entities.map!(x => state.proxy!Entity(x).name));

		if((*gui).button(newItemBox, "New"))
		{
			Entity.create(state, "Item", ArchetypeSet);
			state.setRestorePoint();
		}

		if((*gui).button(deleteItemBox, "Delete") || 
		   gui.keyboard.wasPressed(Key.delete_))
		{
			import std.algorithm;
			selected.base_.sort!((a, b) => b < a);
			foreach(s; selected)
			{
				Entity.destroy(state, entities[s], ArchetypeSet);
			}

			state.setRestorePoint();
			selected.clear();
		}

		SharedData.selected.clear();
		foreach(ref sel; selected)
		{
			SharedData.selected ~= entities[sel];
		}

		if(selected.length == 1)
			SharedData.archetype = entities[selected[0]];
	}
}

enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.panels.entity);
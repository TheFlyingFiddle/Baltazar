module plugin.editor.panels.entity;
import plugin.editor.panels.common;


@EditorPanel("Entities", PanelPos.left)
struct EntityPanel
{
	int selectedArchetype;
	GrowingList!uint selected;
	this(IAllocator all) 
	{
		selected			= GrowingList!(uint)(all);
		selectedArchetype	= 0; 
	}

	void show(PanelContext* context)
	{
		bool changed = false;

		import std.stdio;
		auto gui		   = context.gui;
		auto state		   = Editor.state;

		Rect lp			   = context.area;
		Rect newItemBox    = Rect(lp.x, lp.y, lp.w / 2 - defSpacing, defFieldSize);
		Rect deleteItemBox = Rect(newItemBox.right + defSpacing * 2, lp.y, newItemBox.w, defFieldSize);
		Rect itemBox	   = Rect(lp.x, newItemBox.top + defSpacing, lp.w, lp.h - (newItemBox.top + defSpacing * 2 - lp.y));

		auto e = state.getProperty!(Guid[])(Guid.init, EntitySet);
		auto a = state.getProperty!(Guid[])(Guid.init, ArchetypeSet);
		auto entities   = e ? *e : Guid[].init;
		auto archetypes = a ? *a : Guid[].init; 

		this.selected.clear();
		foreach(ref guid; SharedData.selected)
		{
			auto cnt = entities.countUntil!(x => x == guid);
			if(cnt != -1) this.selected ~= cast(uint)cnt;
		}

		changed = (*gui).listbox(itemBox, selected, entities.map!(x => state.proxy!Entity(x).name));
	
		if((*gui).button(newItemBox, "Add Entity"))
		{
			Guid entity;
			if(selectedArchetype < archetypes.length)
			{
				auto obj    = state.object(archetypes[selectedArchetype]);
				entity = state.createObject();
				state.addToSet(Guid.init, EntitySet, entity);
				foreach(k, v; obj)
					state.setPropertyTyped(entity, k, v);
			}
			else 
			{
				Entity.create(state, "Entity", EntitySet);
			}

			state.setRestorePoint();
	
			selected.clear();
			SharedData.selected.clear();
			SharedData.selected ~= entity;
		}

		auto archNames = archetypes.map!(x => state.proxy!Entity(x).name);
		pragma(msg, typeof(archNames).sizeof);
		(*gui).selectionfield(deleteItemBox, selectedArchetype, archNames);

		if(gui.keyboard.wasPressed(Key.delete_))
		{
			import std.algorithm;
			selected.base_.sort!((a, b) => b < a);
			foreach(s; selected)
				Entity.destroy(state, entities[s], EntitySet);

			state.setRestorePoint();
			selected.clear();
		}

		if(changed)
		{
			SharedData.selected.clear();
			foreach(ref sel; selected)
			{
				SharedData.selected ~= entities[sel];
			}
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
		auto archetypes = e ? *e : Guid[].init;

		this.selected.clear();
		foreach(ref guid; SharedData.selected)
		{
			auto cnt = archetypes.countUntil!(x => x == guid);
			if(cnt != -1) this.selected ~= cast(uint)cnt;
		}

		(*gui).listbox(itemBox, selected, archetypes.map!(x => state.proxy!Entity(x).name));

		if((*gui).button(newItemBox, "New"))
		{
			auto arch = Entity.create(state, "Empty", ArchetypeSet);
			state.setRestorePoint();

			selected.clear();
			selected ~= archetypes.length;
			SharedData.selected.clear();
			SharedData.selected ~= arch;
		}

		if(gui.keyboard.wasPressed(Key.delete_))
		{
			import std.algorithm;
			selected.base_.sort!((a, b) => b < a);
			foreach(s; selected)
			{
				Entity.destroy(state, archetypes[s], ArchetypeSet);
			}

			state.setRestorePoint();
			selected.clear();
		}

		SharedData.selected.clear();
		foreach(ref sel; selected)
		{
			SharedData.selected ~= archetypes[sel];
		}
	}
}

enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.panels.entity);
module plugin.editor.menus;

import bridge.attributes;
import bridge.core;
import plugin.core.data;

@MenuItem("FILE.New.Project")
void new_()
{
	auto files   = Editor.services.locate!(IFileFinder);
	auto save    = files.saveProjectPath();
	if(save)
	{
		Editor.os.save(save);
	}

	Editor.create();

}

@MenuItem("FILE.Open")
void open()
{
	auto files   = Editor.services.locate!(IFileFinder);
	auto path    = files.findOpenProjectPath();
	if(path)
	{
		Editor.os.open(path);
	}
}


@MenuItem("FILE.Save", KeyCommand(KeyModifiers.control, Key.s))
void save()
{
	auto files = Editor.services.locate!(IFileFinder);
	auto path = files.saveProjectPath();
	if(path)
	{
		Editor.os.save(path);
	}
}

@MenuItem("FILE.Save As", KeyCommand(KeyModifiers.control | KeyModifiers.shift, Key.s))
void saveAs()
{
	auto files = Editor.services.locate!(IFileFinder);
	auto path = files.findSaveProjectPath();
	if(path)
	{
		Editor.os.save(path);
	}
}

@MenuItem("FILE.Exit")
void exit()
{
	Editor.close();
}


@MenuItem("EDIT.copy", KeyCommand(KeyModifiers.control, Key.c))
void copy()
{
	//The amounts of things needed to do this is stagering.
	//Though it shows that things are decoupled.
	import allocation, plugin.core.data, std.algorithm;
	import reflection.serialization, content.sdl, bridge.plugins;

	auto state = Editor.state;
	auto db = DataStore(Mallocator.cit);
	scope(exit) db.deallocate();

	auto e = state.getProperty!(Guid[])(Guid.init, EntitySet);
	auto a = state.getProperty!(Guid[])(Guid.init, ArchetypeSet);
	auto entities   = e ? *e : Guid[].init;
	auto archetypes = a ? *a : Guid[].init; 

	foreach(ref guid; SharedData.selected)
	{
		db.addToSet(Guid.init, "copied-objects", guid);
		db.create(guid);
		auto object = state.object(guid);
		foreach(k, v; object)
			db.setProperty(guid, k, v);
		
		if(entities.canFind!(x => x == guid))
			db.addToSet(Guid.init, "entities", guid);
		else if(archetypes.canFind!(x => x == guid))
			db.addToSet(Guid.init, "archetypes", guid);
	}	

	//Staying like this atm.
	auto p = Editor.services.locate!(Plugins);
	MallocAppender!char appender = MallocAppender!char(1024 * 1024);
	auto context = ReflectionContext(p.assemblies.array);
	toSDL(db, appender, &context);
	appender.put('\0');
	Editor.os.clipboardText(appender.take.array);
}

@MenuItem("EDIT.pase", KeyCommand(KeyModifiers.control, Key.v))
void paste()
{
	import allocation, plugin.core.data, std.algorithm, collections.map;
	import reflection.serialization, content.sdl, bridge.plugins;
	
	try
	{
		auto source = Editor.os.clipboardText;

		auto p		 = Editor.services.locate!(Plugins);
		auto context = ReflectionContext(p.assemblies.array);
		auto db		 = fromSDLSource!DataStore(GC.it, source, context);

		auto c		 = db.getProperty(Guid.init, "copied-objects");
		auto e		 = db.getProperty(Guid.init, EntitySet);
		auto a		 = db.getProperty(Guid.init, ArchetypeSet);

		auto copies	    = c ? c.get!(Guid[]) : Guid[].init;
		auto entities   = e ? e.get!(Guid[]) : Guid[].init;
		auto archetypes = a ? a.get!(Guid[]) : Guid[].init; 

		auto renamed = HashMap!(Guid, Guid)(Mallocator.cit);
		scope(exit) renamed.deallocate();

		SharedData.selected.clear();
		foreach(ref copy; copies)
		{
			auto name = Editor.state.createObject();
			SharedData.selected ~= *renamed.add(copy, name);
		}

		//This could be made more generall!	
		foreach(guid, values; db.data)
		{
			if(guid == Guid.init) continue;

			auto name = renamed[guid];
			foreach(k, v; values)
				Editor.state.setProperty(name, k, v);
		}

		foreach(entity; entities)
		{
			Editor.state.addToSet(Guid.init, EntitySet, renamed[entity]);
		}

		foreach(arch; archetypes)
		{
			Editor.state.addToSet(Guid.init, ArchetypeSet, renamed[arch]);
		}

		Editor.state.setRestorePoint();

		//This could be made more generall!
	}
	catch(Throwable t)
	{
		//Might not be a database in the clipboard.
		import log;
		logInfo(t);
	}
}

@MenuItem("EDIT.undo", KeyCommand(KeyModifiers.control, Key.z))
void undo()
{
	auto state = Editor.state();
	state.undo();
}

@MenuItem("EDIT.redo", KeyCommand(KeyModifiers.control | KeyModifiers.shift, Key.z))
void redo()
{
	auto state = Editor.state();
	state.redo();
}

@MenuItem("MODE.entity")
void entityMode()
{
	SharedData.mode = Mode.entity;
}

@MenuItem("MODE.tile")
void tileMode()
{
	SharedData.mode = Mode.tile;
}



import reflection.generation;
enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.menus);
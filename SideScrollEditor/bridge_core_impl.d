module bridge_core_impl;

import bridge.core;
import collections.list;
import reflection;
import allocation;

import util.variant;
import util.hash;
import util.servicelocator;

import std.exception;
import std.random;
import util.variant;
import collections.list;
import collections.map;
import allocation;

struct DataStore
{
	HashMap!(Guid, HashMap!(string, Data)) data;
	this(IAllocator allocator)
	{
		data = HashMap!(Guid, HashMap!(string, Data))(allocator, 4);
		data.add(Guid.init, HashMap!(string, Data)(allocator, 4));
	}

	void deallocate()
	{
		foreach(ref k, ref v; data)
		{
			v.deallocate();
		}

		data.deallocate();
	}

	bool create(Guid guid) nothrow
	{
		return data.tryAdd(guid, HashMap!(string, Data)(data.allocator, 4)) !is null;
	}

	bool destroy(Guid guid) nothrow
	{
		return data.remove(guid);
	}

	bool exists(Guid guid) nothrow
	{
		return data.has(guid);
	}

	bool hasProperty(Guid guid, string key) nothrow
	{
		auto m = guid in data;
		if(m) return m.has(key);
		return false;
	}

	Data* getProperty(Guid guid, string key) nothrow
	{
		auto map = guid in data;
		if(!map) return null;

		return key in (*map);
	}

	bool removeProperty(Guid guid, string key) nothrow
	{
		auto map = &data[guid];
		return map.remove(key); 
	}

	void setProperty(T)(Guid guid, string key, T t) nothrow
	{
		auto map = &data[guid];
		Data* p = key in *map;
		if(!p)
			p = map.add(key, Data());

		*p = t;
	}

	//Need to be fixed so that they use List / GrowingList instead!
	void addToSet(Guid guid, string key, Guid item) nothrow
	{
		auto m = &data[guid];
		Data* p = key in *m;
		if(!p)
		{
			Guid[] guids;
			p = m.add(key, Data(guids));
		}
		//Uses the gc... 
		auto guids = p.peek!(Guid[]);
		*guids ~= item;
	}

	void removeFromSet(Guid guid, string key, Guid item) nothrow
	{
		auto map = &data[guid];
		Data* p = key in *map;
		if(!p)
			return;

		auto guids = p.peek!(Guid[]);

		import std.algorithm;
		auto idx = (*guids).countUntil!(x => x == item);
		if(idx == -1) return;

		*guids = assumeWontThrow((*guids).remove(idx));
	}
}

enum CmdTag : byte
{
	create = 0,
	destroy,
	setProp,
	removeProp,
	addSet,
	removeSet
}

struct Command
{
	nothrow: 
	CmdTag tag;
	Guid guid;

	union
	{
		HashMap!(string, Data) values;
		struct 
		{
			string key;
			union
			{
				Guid   itemGuid;
				Data   data;
			}
		}	
	}

	this(CmdTag tag, Guid guid)
	{
		this.tag  = tag;
		this.guid = guid;
	}
}

class EditorState : IEditorState
{
	DataStore store;

	private GrowingList!(Command) undoCmds;
	private GrowingList!(Command) redoCmds;
	private GrowingList!(uint)	  restorepoints;
	private uint restoreIdx;
	private uint cmdSinceRestore;

	this(IAllocator allocator)
	{
		store			= DataStore(allocator);
		undoCmds		= GrowingList!(Command)(allocator, 1000);
		redoCmds		= GrowingList!(Command)(allocator, 1000);
		restorepoints	= GrowingList!(uint)(allocator, 100); 

		restoreIdx	    = 0;
		cmdSinceRestore = 0;
	}

	void initialize(IAllocator allocator, DataStore store)
	{
		this.store		= store;
		undoCmds		= GrowingList!(Command)(allocator, 1000);
		redoCmds		= GrowingList!(Command)(allocator, 1000);
		restorepoints	= GrowingList!(uint)(allocator, 100); 

		restoreIdx	    = 0;
		cmdSinceRestore = 0;
	}

	void deallocate()
	{
		undoCmds.deallocate();
		redoCmds.deallocate();
		restorepoints.deallocate();
		store.deallocate();
	}

	bool exists(Guid guid) nothrow
	{
		return store.exists(guid);
	}

	bool exists(Guid guid, string key) nothrow
	{
		return store.hasProperty(guid, key);
	}

	HashMap!(string, Data) object(Guid guid) nothrow 
	{
		return store.data[guid];
	}

	Guid createObject() nothrow
	{
		import std.exception;
		//Will be unique!
		while(true)
		{
			auto guid = assumeWontThrow(uniform(0, ulong.max) + 1);
			if(create(guid))
				return guid;
		}
	}

	bool create(Guid guid) nothrow 
	{
		auto res = store.create(guid);
		if(res)
			addCmd(Command(CmdTag.destroy, guid));

		return res;
	}

	bool destroy(Guid guid) nothrow
	{
		if(store.exists(guid))
		{
			auto cmd = Command(CmdTag.create, guid);
			cmd.values = store.data[guid];
			addCmd(cmd);

			return store.destroy(guid);
		}

		return false;
	}
	
	Data* getPropertyTyped(Guid guid, string key) nothrow
	{
		return store.getProperty(guid, key);
	}

	void setPropertyTyped(Guid guid, string key, Data data) nothrow
	{
		if(store.hasProperty(guid, key))
		{
			auto prop = store.getProperty(guid, key);
			if(*prop == data)
				return; //Don't set a property that has not been changed!


			auto cmd = Command(CmdTag.setProp, guid);
			cmd.key  = key;
			cmd.data = store.data[guid][key];
			addCmd(cmd);
		}
		else 
		{
			auto cmd = Command(CmdTag.removeProp, guid);
			cmd.key  = key;
			addCmd(cmd);
		}

		store.setProperty(guid, key, data);
	}

	bool removeProperty(Guid guid, string key) nothrow 
	{
		if(store.hasProperty(guid, key))
		{
			auto cmd = Command(CmdTag.setProp, guid);
			cmd.key  = key;
			cmd.data = store.data[guid][key];
			addCmd(cmd);

			return store.removeProperty(guid, key);
		}

		return false;
	}

	void addToSet(Guid guid, string key, Guid item) nothrow 
	{
		import log; logInfo(guid, " ", key, " ", item, " add to set");

		auto cmd = Command(CmdTag.removeSet, guid);
		cmd.key  = key;
		cmd.itemGuid = item;
		addCmd(cmd);

		store.addToSet(guid, key, item);
	}

	void removeFromSet(Guid guid, string key, Guid item) nothrow 
	{
		auto cmd = Command(CmdTag.addSet, guid);
		cmd.key  = key;
		cmd.itemGuid = item;
		addCmd(cmd);

		store.removeFromSet(guid, key, item);
	}

	void undo() nothrow 
	{
		if(cmdSinceRestore != 0)
			setRestorePoint();

		if(restoreIdx == -1) return;

		foreach(i; 0 .. restorepoints[restoreIdx])
		{
			excecute(undoCmds[$ - i - 1], redoCmds);
		}

		undoCmds.length -= restorepoints[restoreIdx--];
	}

	void redo() nothrow
	{
		if(restoreIdx == restorepoints.length - 1) return;

		foreach(i; 0 .. restorepoints[++restoreIdx])
		{
			excecute(redoCmds[$ - i - 1], undoCmds);
		}

		redoCmds.length -= restorepoints[restoreIdx];
	}

	void setRestorePoint() nothrow 
	{
		if(cmdSinceRestore == 0) return;

		assumeWontThrow(restorepoints ~= cmdSinceRestore);
		restoreIdx	  = restorepoints.length - 1;

		cmdSinceRestore = 0;
	}

	private void addCmd(Command command) nothrow 
	{
		cleanMemory();
		assumeWontThrow(undoCmds ~= command);
		cmdSinceRestore++;
	}

	private void cleanMemory() nothrow 
	{
		scope(failure) return;

		foreach(ref cmd; redoCmds)
		{
			if(cmd.tag == CmdTag.create)
			{
				cmd.values.deallocate();
			}	
		}

		if(redoCmds.length != 0)
		{
			redoCmds.length = 0;
			restorepoints.length = restoreIdx + 1;
		}
	}

	private void excecute(Command command, ref GrowingList!Command stack) nothrow 
	{
		Command inverse;
		final switch(command.tag)
		{
			case CmdTag.create: 
				inverse = Command(CmdTag.destroy, command.guid);
				store.data.add(command.guid, command.values);
				break;
			case CmdTag.destroy: 
				inverse = Command(CmdTag.create, command.guid);
				inverse.values = store.data[command.guid];
				store.destroy(command.guid);
				break;
			case CmdTag.addSet:
				inverse = Command(CmdTag.removeSet, command.guid);
				inverse.key  = command.key;
				inverse.itemGuid = command.itemGuid;

				store.addToSet(command.guid, command.key, command.itemGuid);
				break;
			case CmdTag.removeSet: 
				inverse = Command(CmdTag.addSet, command.guid);
				inverse.key  = command.key;
				inverse.itemGuid = command.itemGuid;

				store.removeFromSet(command.guid, command.key, command.itemGuid);
				break;
			case CmdTag.setProp: 
				if(store.hasProperty(command.guid, command.key))
				{
					inverse = Command(CmdTag.setProp, command.guid);
					inverse.key  = command.key;
					inverse.data = store.data[command.guid][command.key];
				}
				else 
				{
					inverse = Command(CmdTag.removeProp, command.guid);
					inverse.key  = command.key;
				}

				store.setProperty(command.guid, command.key, command.data);
				break;
			case CmdTag.removeProp: 
				inverse = Command(CmdTag.setProp, command.guid);
				inverse.key  = command.key;
				inverse.data = store.data[command.guid][command.key];

				store.removeProperty(command.guid, command.key);
				break;
		}

		assumeWontThrow(stack ~= inverse);
	}

}



class EditorServiceLocator : IServiceLocator
{
	ServiceLocator* locator;
	this(ServiceLocator* locator)
	{
		this.locator = locator;
	}

	override void* locateService(TypeHash th, string name) nothrow
	{
		return locator.tryFind(th, name);
	}

	override void addService(void* service, TypeHash hash, string name) nothrow
	{
		locator.add(service, hash, name);
	}
}

class Assets : IAssets
{
	import std.algorithm;
	import content;

	struct TypedAssets
	{
		string type;
		List!Asset assets;
	}

	AsyncContentLoader* loader;
	List!(TypedAssets) typed;
	this(IAllocator allocator, AsyncContentLoader* loader)
	{
		import std.path;
		this.loader = loader;
		this.typed = List!TypedAssets(allocator, 15);
		
		auto files = loader.avalibleResources;
		foreach(item; files.dependencies)
		{
			string ext  = item.name.extension[1 .. $];
			string name = item.name.stripExtension;
			auto idx = typed.countUntil!(x => x.type == ext);
			if(idx == -1)
			{
				typed ~= TypedAssets(ext, List!Asset(allocator, 100));
				idx = typed.length - 1;
			}	

			Asset a;
			a.name		= name;
			a.subitems  = List!(string)(allocator, item.deps.length);
			a.subitems ~= item.deps.map!(x => x.stripExtension);

			typed[idx].assets ~= a;
		}
	}

	override List!Asset loadedAssets(string type) nothrow
	{
		scope (failure) return List!(Asset).init;

		import std.algorithm;
		return typed.find!(x => x.type == type)[0].assets;
	}

	override void* locateAsset(TypeHash type, string asset) nothrow
	{
		auto a = loader.getItem(asset);
		if(a.typeHash == type)
			return a.item;
		else 
			return null;
	}
}
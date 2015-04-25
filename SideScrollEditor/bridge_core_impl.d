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



enum CmdTag : byte
{
	create = 0,
	destroy,
	setProp,
	removeProp, 
	addSet,
	removeSet,

	//Arrays!
	setIndex,
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
				//add/remove from set.
				Guid   itemGuid;
				
				//SetProperty
				Data   data;

				//Array operations.
				struct 
				{
					align(1):
					ushort arrayIndex; // <- PROBLEM! Need to devide into 24 bit and 8 bit.
					ushort itemSize;
					ubyte[8] itemValue;
				}
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
	private ulong objectCounter;

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
			auto guid = ++objectCounter;
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

	void setArrayTyped(Guid guid, string key, uint capacity, uint size, TypeHash array) nothrow
	{
		scope(failure) return;
		//Removed data stays forever as it is now. (Works well enough :))
		auto mem   = cast(ubyte[])Mallocator.it.allocateRaw(capacity * size, size);
		mem[] = 0;
		mem.length = capacity;
		Data data;
		data.id = array;
		*(cast(void[]*)data.data.ptr) = mem;

		setPropertyTyped(guid, key, data);
	}

	void setArrayElement(Guid guid, string key, uint index, ubyte[] item, TypeHash arrType) nothrow
	{
		auto array = store.getProperty(guid, key);
		if(array)
		{
			assert(array.id == arrType);

			int size = item.length;
			auto d    = *cast(ubyte[]*)array.data;
			auto data = d.ptr;
			assert(d.length > index, "Range exception!");
			
			auto cmd	   = Command(CmdTag.setIndex, guid);
			cmd.key		   = key;
			cmd.arrayIndex = cast(ushort)index;
			cmd.itemSize   = cast(ushort)size;

			import log;
			logInfo(size, " ", d.length, " ", guid, " ", key, " ", index, " " , item);
			cmd.itemValue[0 .. size] = data[index * size .. index * size + size];
			addCmd(cmd);
			
			data[index * size .. index * size + size] = item;
			return;
		}
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
			case CmdTag.setIndex:
				inverse			   = Command(CmdTag.setIndex, command.guid);
				inverse.key		   = command.key;
				inverse.itemSize   = command.itemSize;
				inverse.arrayIndex = command.arrayIndex;

				auto array = store.getProperty(command.guid, command.key);
				auto data = (*cast(ubyte[]*)array.data).ptr;
				inverse.itemValue[0 .. command.itemSize] = data[command.arrayIndex * command.itemSize .. command.arrayIndex * command.itemSize + command.itemSize];
				data[command.arrayIndex * command.itemSize .. command.arrayIndex * command.itemSize + command.itemSize] = command.itemValue[0 .. command.itemSize];
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
		scope(failure) return null;
		auto a = loader.load(type, asset);
		if(a.typeHash == type)
			return a.item;
		else 
			return null;
	}
}
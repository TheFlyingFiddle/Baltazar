module bridge_core_impl;

import bridge.core;
import bridge.data;
import collections.list;
import reflection;
import allocation;

import util.variant;
import util.hash;
import util.servicelocator;

import std.exception;
import std.random;
import util.variant;
import std.bitmanip;
import collections.list;
import collections.map;
import allocation;



enum CmdTag : byte
{
	create = 0,
	destroy,
	setProp,
	removeProp, 

	//Arrays!
	setElement,
	appendElement,
	unappendElement,
	insertElement,
	removeElementAt,
	removeElement

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
				//SetProperty
				Data   data;

				//Array operations.
				struct 
				{
					align(1):
					mixin(bitfields!(uint, "arrayIndex", 24,
									 uint, "itemSize", 8));
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
	private uint objectCounter;

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
	
	Data* getProperty(Guid guid, string key) nothrow
	{
		return store.getProperty(guid, key);
	}

	ubyte[] getArrayElement(Guid guid, string key, uint index) nothrow
	{
		return store.getArrayElement(guid, key, index);
	}
	
	void setProperty(Guid guid, string key, Data data) nothrow
	{
		if(store.hasProperty(guid, key))
		{
			auto prop = store.getProperty(guid, key);
			if(*prop == data)
			{
				return; //Don't set a property that has not been changed!
			}

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

	void setArrayProperty(Guid guid, string key, uint capacity, ArrayElementTag tag) nothrow
	{
		assert(!store.hasProperty(guid, key));
		store.setArrayProperty(guid, key, tag, capacity);

		auto cmd = Command(CmdTag.removeProp, guid);
		cmd.key  = key;
		addCmd(cmd);
	}

	void setArrayElement(Guid guid, string key, uint index, ubyte[] value) nothrow
	{
		auto arr = store.getProperty(guid, key);

		auto cmd = Command(CmdTag.setElement, guid);
		cmd.key  = key;
		cmd.arrayIndex = index;
		cmd.itemSize   = value.length;
		cmd.itemValue[0 .. value.length] = store.getArrayElement(guid, key, index);
		addCmd(cmd);

		store.setArrayElement(guid, key, index, value);
	}

	void appendArrayElement(Guid guid, string key, ubyte[] value, ArrayElementTag tag) nothrow
	{
		auto prop = getProperty(guid, key);
		if(!prop)
		{
			setArrayProperty(guid, key, 8, tag);
		}


		auto cmd = Command(CmdTag.unappendElement, guid);
		cmd.key  = key;
		cmd.itemSize = value.length;
		addCmd(cmd);

		store.appendArrayElement(guid, key, value);
	}

	void insertArrayElement(Guid guid, string key, uint index, ubyte[] value) nothrow
	{
		auto cmd	    = Command(CmdTag.removeElementAt, guid);
		cmd.key		    = key;
		cmd.arrayIndex  = index;
		cmd.itemSize	= value.length;
		cmd.itemValue[0 .. value.length]   = value[];
		addCmd(cmd);

		store.insertArrayElement(guid, key, index, value);
	}

	void removeArrayElementAt(Guid guid, string key, uint index) nothrow
	{
		auto value = store.getArrayElement(guid, key, index); 

		auto cmd = Command(CmdTag.insertElement, guid);
		cmd.key  = key;
		cmd.arrayIndex = index;
		cmd.itemSize   = value.length;
		cmd.itemValue[0 .. value.length] = value[];
		addCmd(cmd);

		store.removeArrayElementAt(guid, key, index);
	}

	void removeArrayElement(Guid guid, string key, ubyte[] value) nothrow
	{
		auto index = store.indexOfArrayElement(guid, key, value);
		if(index == -1) return;
		
		auto cmd = Command(CmdTag.insertElement, guid);
		cmd.key  = key;
		cmd.arrayIndex = index;
		cmd.itemSize   = value.length;
		cmd.itemValue[0 .. value.length] = value[];
		addCmd(cmd);
		store.removeArrayElementAt(guid, key, index);
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
				inverse		= Command(CmdTag.destroy, command.guid);
				store.data.add(command.guid, command.values);
			break;
			case CmdTag.destroy:
				inverse		   = Command(CmdTag.create, command.guid);
				inverse.values = store.data[command.guid];
				store.destroy(command.guid);
			break;
			case CmdTag.setProp:
				if(store.hasProperty(command.guid, command.key))
				{
					inverse     = Command(CmdTag.setProp, command.guid);
					inverse.key = command.key;
					inverse.data = store.data[command.guid][command.key];
				}
				else 
				{
					inverse     = Command(CmdTag.removeProp, command.guid);
					inverse.key = command.key;
				}
				store.setProperty(command.guid, command.key, command.data);
			break;
			case CmdTag.removeProp:
				inverse = Command(CmdTag.setProp, command.guid);
				inverse.key  = command.key;
				inverse.data = store.data[command.guid][command.key];

				store.removeProperty(command.guid, command.key);
			break;
			case CmdTag.setElement:
				inverse = Command(CmdTag.setElement, command.guid);
				inverse.key = command.key;
				inverse.arrayIndex = command.arrayIndex;
				inverse.itemSize  = command.itemSize;
				inverse.itemValue[0 .. command.itemSize] = store.getArrayElement(command.guid, command.key, command.arrayIndex);

				store.setArrayElement(command.guid, command.key, command.arrayIndex, command.itemValue[0 .. command.itemSize]);
				break;
			case CmdTag.appendElement:
				inverse = Command(CmdTag.unappendElement, command.guid);
				inverse.key = command.key;
				inverse.itemSize = command.itemSize;

				store.appendArrayElement(command.guid, command.key, command.itemValue[0 .. command.itemSize]);
			break;
			case CmdTag.unappendElement:
				auto arr = store.getProperty(command.guid, command.key);
				inverse = Command(CmdTag.appendElement, command.guid);
				inverse.key		   = command.key;
				inverse.arrayIndex = arr.meta - 1;
				inverse.itemSize   = command.itemSize;
				inverse.itemValue[0 .. command.itemSize] = store.getArrayElement(command.guid, command.key, arr.meta - 1);

				store.removeArrayElementAt(command.guid, command.key, arr.meta - 1);
			break;
			case CmdTag.insertElement:
				inverse = command;
				inverse.tag = CmdTag.removeElementAt;
				store.insertArrayElement(command.guid, command.key, command.arrayIndex, command.itemValue[0 .. command.itemSize]);
				
				break;
			case CmdTag.removeElementAt:
			case CmdTag.removeElement:
				inverse = command;
				inverse.tag = CmdTag.insertElement;
				store.removeArrayElementAt(command.guid, command.key, command.arrayIndex);
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

	override Handle* locateAsset(TypeHash type, string asset) nothrow
	{
		scope(failure) return null;
		auto a = loader.load(type, asset);
		if(a.typeHash == type)
			return a;
		else 
			return null;
	}
}
module db;

import std.bitmanip;
import allocation;
import util.hash;
import util.traits;
import collections.list;
import collections.map;
import collections.deque;

alias ValueID = HashID;

struct TypeDescriptor
{
	struct Field
	{
		string fieldName;
		TypeHash type;
		ushort	 size;
		ushort	 aligno;
	}

	TypeHash type;
	size_t   size;
	Field[] fields;

	static TypeDescriptor make(T)() if(isAggregateType!T)
	{
		Field[] f;
		foreach(i, dummy; T.init.tupleof)
		{
			enum name = T.tupleof[i].stringof;
			enum hash = typeHash!(typeof(dummy));
			enum size = typeof(dummy).sizeof;
			mixin("enum aligno = T. " ~ name ~ ".alignof;");

			f ~= Field(name, hash, size, aligno);
		}

		return TypeDescriptor(typeHash!T, T.sizeof, f);
	}

	static TypeDescriptor make(T)() if(isBasicType!T)
	{
		return TypeDescriptor(typeHash!T, T.sizeof, null);
	}
}

struct ValueIndex
{
	mixin(bitfields!(
		  uint, "index", 24, 
		  uint, "sizeIndex",  8));

	
	void toString(scope void delegate(const(char)[]) sink) const
	{
		import util.strings;
		sink(text1024("Index: ", this.index));
		sink(text1024("Size:  ", this.sizeIndex));
	}

}

struct Guid
{
	mixin(bitfields!(
		  uint, "index", 24,
		  uint, "generation", 8));


	void toString(scope void delegate(const(char)[]) sink) const
	{
		import util.strings;
		sink(text1024("Index: ", this.index));
		sink(text1024("Generation:  ", this.generation));
	}
}

struct DBItem
{
	mixin(bitfields!(
		  uint, "index", 24,
		  uint, "length", 8)); 

	static uint byteLength(uint length)
	{
		return length * (ValueID.sizeof + ValueIndex.sizeof);
	}
}

struct GuidManager 
{
	GrowingList!(ubyte) guids;
	Deque!(uint)		freeIndices;

	this(IAllocator allocator, uint size)
	{
		guids		= GrowingList!(ubyte)(allocator, size);
		freeIndices = Deque!(uint)(allocator, 10);
	}

	Guid create() 
	{	
		Guid g;
		if(freeIndices.length > 1024)
		{
			g.index = freeIndices.dequeue();
			g.generation = guids[g.index];
		}
		else 
		{
			g.index		 = guids.length;
			g.generation = 0;
			guids ~= 0;
		}
		return g; 
	}

	void destroy(Guid guid) 
	{
		auto idx = guid.index;
		guids[idx]++;
		freeIndices.push(idx);
	}

	bool alive(Guid guid) 
	{
		return guids[guid.index] == guid.generation;
	}
}

struct FreeList
{
	IAllocator allocator;
	uint   capacity;
	uint   length;
	uint   allocSize;
	uint   nextFree;
	ubyte* memory;
	
	this(IAllocator allocator, uint allocSize, uint initialCapacity)
	{
		assert(allocSize >= 4);
		//Allocate here. 
		this.allocator = allocator;
		this.allocSize = allocSize == 0 ? 4 : allocSize;
		this.capacity  = initialCapacity;
		this.nextFree  = 0;

		memory = cast(ubyte*)allocator.allocateRaw(this.allocSize * capacity, 4).ptr;
		foreach(i; 0 .. capacity)
		{
			auto ptr = cast(uint*)(memory + i * allocSize);
			*ptr     = i + 1;
		}
	}

	uint allocate() 
	{
		if(length == capacity)
			resize();

		auto old = nextFree;
		nextFree = *cast(uint*)(memory + nextFree * allocSize);
		length++;
		return old;
	}

	void deallocate(uint item) 
	{
		auto ptr = cast(uint*)(memory + item * allocSize);
		*ptr = nextFree;
		nextFree = item;
	}

	void[] get(uint item) 
	{ 
		auto ptr = cast(ubyte*)(memory + item * allocSize);
		return ptr[0 .. allocSize]; 
	}

	private void resize()
	{
		auto newCap = capacity * 2 + 10;
		auto mem = cast(ubyte*)allocator.allocateRaw(this.allocSize * newCap, 4).ptr;
		foreach(i; capacity .. newCap)
		{
			auto ptr = cast(uint*)(mem + i * allocSize);
			*ptr     = capacity + i + 1;
		}

		mem[0 .. this.allocSize * capacity] = memory[0 .. this.allocSize * capacity];
		allocator.deallocate(cast(void[])memory[0 .. this.allocSize * capacity]);
		
		memory   = mem;
		capacity = newCap;
	}
}

private __gshared static HashMap!(TypeHash, TypeDescriptor) descriptors;
private __gshared static HashMap!(ValueID,  string)		    idToString;

__gshared static this()
{
	descriptors = HashMap!(TypeHash, TypeDescriptor)(Mallocator.cit);
	idToString  = HashMap!(ValueID,  string)(Mallocator.cit);
}

struct TypedData
{
	void[] rep;

	ref TypeHash type() const { return *cast(TypeHash*)rep.ptr; } 
	void*		 data()  { return &rep[4]; }
	uint		 size() const { return rep.length - 4; }


	void toString(scope void delegate(const(char)[]) sink) const
	{
		import util.strings;
		sink(text1024("Type: ",  this.type));
		sink(text1024(" Size: ", this.size));
	}
}

struct ArrayTag { }
struct ArrayData
{
	void[] rep;
	ref TypeHash elementType() const { return *cast(TypeHash*)rep.ptr; }
	ref uint	 length()			 { return *(cast(uint*)&rep[4]);   }
	ref uint	 capacity()			 { return *(cast(uint*)&rep[8]);   }	
	ref uint	 elemSize()			 { return *(cast(uint*)&rep[12]);  }
	ref void*	 data()				 { return *(cast(void**)&rep[16]); }

	
	void add(IAllocator allocator, void[] value)
	{
		import log;
		if(length == capacity)
		{
			auto size = capacity * elemSize;
			auto mem = allocator.allocateRaw(size * 2 + 10, 8);
			logInfo("Allocated memory: ", mem.ptr);
			mem[0 .. size] = data[0 .. size];
			deallocate(allocator);
			data = mem.ptr;
			logInfo("Allocated memory: into ", data);

			capacity = capacity * 2 + 10;
		}

		auto idx = elemSize * length;
		data[idx .. idx + elemSize] = value;
		length = length + 1;

		logInfo("Allocated memory: into ", data);
		logInfo(this);
	}

	void remove(IAllocator allocator, uint index)
	{
		if(index > length)
			assert(0, "Cannot remove beyond the bounds of the array!");

		auto first = elemSize * index;
		foreach(i; index .. length - 1)
		{
			auto idx = first + i * elemSize;
			data[idx .. idx + elemSize] = data[idx + elemSize .. idx + elemSize * 2];
		}

		length = length - 1;
		if(length == 0)
		{
			capacity = 0;
			allocator.deallocate(data[0 .. elemSize * capacity]);
		}
	}

	void deallocate(IAllocator allocator)
	{
		if(capacity > 0)
		{
			allocator.deallocate(data[0 .. elemSize * capacity]);
		}
	}

	void toString(scope void delegate(const(char)[]) sink) const
	{
		import util.strings;
		sink(text1024("Type: ",  this.elementType));
		sink(text1024(" length: ", *(cast(uint*)&rep[4])));
		sink(text1024(" capacity: ", *(cast(uint*)&rep[8])));
		sink(text1024(" elemSize: ", *(cast(uint*)&rep[12])));
		sink(text1024(" data: ", *(cast(void**)&rep[16])));
	}
}

struct Database
{
	enum NotInitialized = 2^^24 - 1;
	__gshared static allocSizes = [8,16,24,32,64,256,1024,2048];

	IAllocator allocator;
	DBItem[] items;
	GuidManager generator;
	FreeList[8] freelists; 
	Guid root;

	this(IAllocator allocator, uint initialCapacity)
	{
		this.allocator = allocator;
		items     = allocator.allocate!(DBItem[])(initialCapacity);
		generator = GuidManager(allocator, initialCapacity);

		//8 diffrent item sizes now. Could be overkill
		freelists[0] = FreeList(allocator, 8,    10);
		freelists[1] = FreeList(allocator, 16,   10);
		freelists[2] = FreeList(allocator, 24,   10);
		freelists[3] = FreeList(allocator, 32,   10);
		freelists[4] = FreeList(allocator, 64,   10);
		//Values are rarly larger then this.

		//How many properties can be 
		freelists[5] = FreeList(allocator, 256,  0);
		freelists[6] = FreeList(allocator, 1024, 0);
		freelists[7] = FreeList(allocator, 2048, 0); //Largest possible item

		//This would imply that items such as 
		//struct BarFuncle { ubyte[1024] buffer; uint trololo; } can be stored in the db.
		//And indeed they can.
		//Only arrays may be larger then 2048 bytes.

		foreach(ref item; items)
		{
			item.length = 0;
			item.index  = NotInitialized;
		}
		
		root = create();
	}

	Guid rootObject()
	{
		return root;
	}

	Guid create()
	{
		return generator.create();
	}

	bool destroy(Guid guid)
	{
		if(generator.alive(guid))
		{
			deallocateItem(items[guid.index]); //Do we want to deallocate? Yes we do :)
			generator.destroy(guid);
			return true;
		}

		return false;
	}


	void addProperty(Guid guid,
					 string id,
					 TypeDescriptor descriptor,
					 void[] initialValue)
	{
		auto hash = HashID(id);
		idToString.tryAdd(hash, id); //This way we ensure that we can do everything and 
									 //basic operations are still fast :)

		auto desc = descriptor.type in descriptors;
		if(!desc)
			desc = descriptors.add(descriptor.type, descriptor);
		
		
		//This is an add operation with all that this implies.
		auto idx = allocateValue(desc.type, initialValue);
		addProperty(guid, hash, idx);
	}

	void removeProperty(Guid guid, ValueID id)
	{
		if(!generator.alive(guid)) return ;

		//Removals do not shrink the item array. (Unless it is empty.
		auto item  = &items[guid.index];
		auto range = itemRange(*item);
		foreach(i; 0 .. item.length) if(range.ids[i] == id)
		{
			auto value = typedValue(range.indices[i]);
			if(value.type == typeHash!ArrayTag)
			{
				auto array = ArrayData(value.data[0 .. value.size]);
				array.deallocate(allocator);
			}

			deallocateValue(range.indices[i]);
			range.ids[i]		= range.ids[item.length - 1];
			range.indices[i]	= range.indices[item.length - 1];
			item.length			= item.length - 1;		
			break;
		}

		if(item.length == 0)
			deallocateItem(*item);
	}

	void setProperty(Guid guid, 
					 ValueID id,
					 TypeHash hash,
					 void[] data)
	{
		if(!generator.alive(guid)) return;

		auto item  = items[guid.index];
		auto range = itemRange(item);
		import log;
		logInfo(item.length);

		foreach(i; 0 .. item.length) 
			if(id == range.ids[i])
		{
			logInfo(i, id);

			auto value = typedValue(range.indices[i]);
			if(hash == value.type) {
				value.data[0 .. data.length] = data; //Common case
			} else if(sameAllocator(allocSizes[value.size], data.length)) {
				value.type	 = hash;
				value.data[0 .. data.length] = data;
			} else {
				//We have changed the type of an item to a diffrent 
				//type of a diffrent size :S
				deallocateValue(range.indices[i]);	
				auto idx = allocateValue(hash, data);
				range.indices[i] = idx;
			}	

			return;
		}

		assert(0, "Property does not exist");
	}

	import log;
	void[] getProperty(Guid guid,
					   ValueID id,
					   TypeHash hash)
	{
		if(!generator.alive(guid)) return null;

		auto item  = items[guid.index];
		auto range = itemRange(item);
		foreach(i; 0 .. item.length) if(id == range.ids[i])
		{
			auto value = typedValue(range.indices[i]);
			if(hash == value.type)
				return value.data[0 .. value.size];
		}

		//Property does not exist basically.
		return null;
	}

	void addArrayProperty(Guid guid,
						  string id,
						  TypeDescriptor descriptor)
	{
		auto hash = HashID(id);
		idToString.tryAdd(hash, id); //This way we ensure that we can do everything and 
		//basic operations are still fast :)

		auto desc = descriptor.type in descriptors;
		if(!desc)
			desc = descriptors.add(descriptor.type, descriptor);


		//Create an array, add an element to it 
		//and add a property to this guid for it.
		ubyte[28] tmp;
		auto arr = ArrayData(cast(void[])tmp[]);
		arr.elementType = desc.type;
		arr.elemSize	= desc.size;
		arr.length		= 0;
		arr.capacity	= 0;

		auto idx = allocateValue(typeHash!ArrayTag, tmp[]);
		addProperty(guid, hash, idx);
	}

	//This is an array. --Hold of on this one for now.
	void addArrayProperty(Guid guid,
				  ValueID id,
				  TypeHash hash,
				  void[] element)
	{
		if(!generator.alive(guid)) return;

		auto item  = items[guid.index];
		auto range = itemRange(item);
		foreach(i; 0 .. item.length) if(id == range.ids[i])
		{
			auto value = typedValue(range.indices[i]);
			if(value.type == typeHash!ArrayTag)
			{
				auto array = ArrayData(value.data[0 .. value.size]);
				if(array.elementType == hash)
					array.add(allocator, element);
				else 
					assert(0, "Cannot push incorrect type int array!");

				return;
			}
			else 
			{
				assert(0, "Cannot push into non array type!");
			}
		}


		assert(0, "Failed to find array id");
	
	}

	void removeArrayElement(Guid guid,
					 ValueID id,
					 size_t	 index)
	{
		if(!generator.alive(guid)) return;

		auto item  = items[guid.index];
		auto range = itemRange(item);
		foreach(i; 0 .. item.length) if(id == range.ids[i])
		{
			auto value = typedValue(range.indices[i]);
			if(value.type == typeHash!ArrayTag)
			{
				auto array = ArrayData(value.data[0 .. value.size]);
				array.remove(allocator, index);
			}
			else 
			{
				assert(0, "Cannot remove from non array type!");
			}
		}

	}

	private auto itemRange(DBItem item)
	{	
		struct Range
		{
			ValueID* ids;
			ValueIndex* indices;
		}
		
		if(item.index != NotInitialized)
		{
			auto fi   = freelist(DBItem.byteLength(item.length));
			auto mem  = fi.get(item.index);

			return Range(cast(ValueID*)mem.ptr,cast(ValueIndex*)(mem.ptr + ValueID.sizeof * item.length));
		}
		else 
		{
			return Range(null, null);
		}	
	}

	//This is suprisingly complex due to the fact that 
	//The arrays themselfs are also stored in the freelists :P
	private void addProperty(Guid guid, ValueID id, ValueIndex idx)
	{
		import log;
		logInfo("Adding prop: ", guid, " ", id, " ", idx);


		//Will not move memory for Removals just for additions.
		auto item  = &items[guid.index];
		auto size0 = DBItem.byteLength(item.length);
		auto size1 = DBItem.byteLength(item.length + 1);
		if(size0 == 0)
		{
			//Not yet actually allocated any space for properties.
			auto index  = allocateValueSpace(1);
			item.index  = index;
			item.length = 1;
				
			auto range = itemRange(*item);
			range.ids[0]	 = id;
			range.indices[0] = idx;
		}
		else if(sameAllocator(size0, size1))
		{
			item.length = item.length + 1;
			auto range = itemRange(*item);
			range.ids[item.length - 1] = id;
			range.indices[item.length - 1] = idx;
		} 
		else 
		{
			auto nItemIdx   = allocateValueSpace(item.length + 1);
			
			DBItem nItem;
			nItem.index = nItemIdx;
			nItem.length = item.length + 1;

			auto range		= itemRange(*item);
			auto nRange		= itemRange(nItem);
			foreach(i; 0 .. item.length)
			{
				nRange.ids[i] = range.ids[i];
				nRange.indices[i] = range.indices[i];
			}

			nRange.ids[item.length]		= id;
			nRange.indices[item.length] = idx;
			
			deallocateValueSpace(*item);
			*item = nItem;
		}
	}

	private uint allocateValueSpace(uint length)
	{
		auto fi    = freelist(DBItem.byteLength(length));
		return fi.allocate();
	}

	private FreeList* freelist(uint size)
	{
		return &freelists[freelistIndex(size)];
	}	

	private uint freelistIndex(uint size)
	{
		import util.traits;
		import std.typetuple;
		struct R { uint low, high; }
		foreach(i, val; TypeTuple!(R(0, 8),
								   R(8, 16),
								   R(16, 24),
								   R(24, 32),
								   R(32, 64),
								   R(64, 256),
								   R(256, 1024),
								   R(1024, 2048)))
		{
			if(val.low < size && size <= val.high)
			{
				return i;
			}
		}

		//Larger then largest freelist!
		return 8;
	}

	private bool sameAllocator(uint size0, uint size1)
	{
		return freelistIndex(size0) == freelistIndex(size1);
	}

	private TypedData typedValue(ValueIndex index)
	{
		auto fi  = &freelists[index.sizeIndex];
		return TypedData(fi.get(index.index));
	}

	private ValueIndex allocateValue(TypeHash hash, void[] value)
	{
		immutable size = TypeHash.sizeof + value.length;
		assert(size <= 2048);

		auto frIdx = freelistIndex(size);
		auto fr	   = &freelists[frIdx];
		auto aidx  = fr.allocate();

		auto data  = fr.get(aidx).ptr;
		*(cast(TypeHash*)data) = hash;
		data[TypeHash.sizeof .. size] = value;

		ValueIndex idx;
		idx.index	  = aidx;
		idx.sizeIndex = frIdx;

		return  idx;
	}

	private void deallocateValue(ValueIndex index)
	{
		auto fi  = &freelists[index.sizeIndex];
		fi.deallocate(index.index);
	}

	private void deallocateValueSpace(DBItem item)
	{
		auto fi = freelist(DBItem.byteLength(item.length));
		fi.deallocate(item.index);
	}

	private void deallocateItem(ref DBItem item)
	{
		auto range = itemRange(item);
		foreach(i; 0 .. item.length)
		{
			deallocateValue(range.indices[i]);
		}

		auto fi = freelist(DBItem.byteLength(item.length));
		fi.deallocate(item.index);
		item.index	= NotInitialized;
		item.length = 0;
	}

	void addProp(T)(Guid guid, string id, T value) if(!hasIndirections!T)
	{
		this.addProperty(guid, id, TypeDescriptor.make!T, cast(void[])(&value)[0 .. 1]);
	}

	void addArrayProp(T)(Guid guid, string id) if(!hasIndirections!T)
	{
		this.addArrayProperty(guid, id, TypeDescriptor.make!T);
	}

	void setProp(T)(Guid guid, string id, T value) if(!hasIndirections!T)
	{
		import log;
		auto hash = HashID(id);
		logInfo("SetProp: ", guid, id, hash);

		auto val  = cast(void[])(&value)[0 .. 1];
		setProperty(guid, hash, typeHash!T, val);
	}

	T* getProp(T)(Guid guid, string id) if(!hasIndirections!T)
	{
		import log;
		auto hash  = HashID(id);
		logInfo("GetProp: ", guid, id, hash);

		auto value = getProperty(guid, hash, typeHash!T);
		return cast(T*)value.ptr;
	}

	DBArray!(T) getArray(T)(Guid guid, string id) if(!hasIndirections!T)
	{
		auto hash = HashID(id);
		DBArray!T array = DBArray!T(&this, guid, hash);
		return array;
	}

	bool hasProperty(Guid guid, string strid)
	{
		auto id	   = HashID(strid);
		return hasProperty(guid, id);
	}
	
	bool hasProperty(Guid guid, ValueID id)
	{
		if(!generator.alive(guid)) return false;

		auto item  = items[guid.index];
		auto range = itemRange(item);
		foreach(i; 0 .. item.length) if(id == range.ids[i])
			return true;

		return false;
	}

	void addArray(T)(Guid guid, string id, T value) if(!hasIndirections!T)
	{
		auto hash = HashID(id);
		auto val  = cast(void[])(&value)[0 .. 1];
		data.addArray(guid, hash, typeHash!T, val);
	}

	void removeArray(T)(Guid guid, string id, uint index) if(!hasIndirections!T)
	{
		data.removeArray(guid, HashID(id), index);
	}
}

struct DBArray(T) if(!hasIndirections!T)
{
	Database* db;
	Guid guid;
	ValueID key;

	T[] get() //Gets a pointer to the underlying storage.
	{
		auto arrData = ArrayData(db.getProperty(guid, key, typeHash!ArrayTag));
		return cast(T[])arrData.data[0 .. T.sizeof * arrData.length];
	}

	void add(T item)
	{
		db.addArrayProperty(guid, key,  typeHash!T, cast(void[])(&item)[0 .. 1]);
	}

	void removeAt(uint idx)
	{
		db.removeArrayElement(guid, key, idx);
	}
}

struct Complexo
{
	int a;
	int b;
	long d;
}

unittest
{
	Database data = Database(Mallocator.cit, 10);

	try
	{
		auto guid = data.create();
		data.addProp!int(guid, "Test", 123456);
		data.addProp!long(guid, "Test2", 1423);
		data.addProp!Complexo(guid, "Test3", Complexo(1, 2, 321));
		data.addArrayProp!int(guid, "Test4");

		assert(*data.getProp!int(guid, "Test") == 123456);
		assert(*data.getProp!long(guid, "Test2") == 1423);
		assert(*data.getProp!Complexo(guid, "Test3") == Complexo(1, 2, 321));

		auto arr = data.getArray!int(guid, "Test4");
		arr.add(1);
		assert(arr.get() == [1]);
		arr.add(2);
		assert(arr.get() == [1, 2]);
		arr.add(3);
		assert(arr.get() == [1, 2, 3]);
		arr.add(4);
		assert(arr.get() == [1, 2, 3, 4]);
		arr.removeAt(1);
		assert(arr.get() == [1, 2, 4]);

		data.removeProperty(guid, HashID("Test4"));
		assert(!data.hasProperty(guid, "Test4"));

	} 
	catch(Throwable t)
	{
		import log;
		logInfo(t);
	}
}



//You can store arrays and 
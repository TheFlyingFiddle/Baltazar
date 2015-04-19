module dbresource;
import db;

void saveBinary(ref Database db, ubyte[] sink)
{
	import util.bitmanip;
	size_t offset = 0;

	sink.write!uint(db.items.length, &offset);
	sink[offset .. numItems * DBItem.sizeof] = db.items;
	offset += numItems * DBItem.sizeof;




}

Database loadBinary(IAllocator allocator,
					ubyte[]	   data)
{
	return Database.init;
}


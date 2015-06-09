module SOA;

void save(Sink)(DataStore store, ref Sink sink)
{
	auto e = store.getProperty!(Guid[])(Guid.init);
	sink.write!uint(e.length);
	sink.write!uint(ComponentTypes.length);
	foreach(comp; ComponentTypes)
	{
		auto s = sink.save();
		sink.write!uint(0); 
		uint count = 0;
		foreach(guid; *e)
		{
			if(Entity.hasComponent!comp(guid))
			{
				count++;
				auto c = state.proxy!comp(guid);
				sink.save(c);
			}
		}
		s.write!uint(count);
	}

	//This should be sufficient.
}
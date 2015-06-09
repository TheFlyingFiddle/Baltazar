module pluginshared.componentmeta;

struct Component { }
mixin template ComponentBindings(alias Module)
{
	import bridge.core : PluginSetup, IEditor;
	@PluginSetup void initialize_component_bindings(IEditor editor) 
	{
		import util.hash : HashID;
		import util.traits : Structs, hasAttribute;
		import pluginshared.data;
		import allocation;

		auto service = editor.services.locate!(MetaComponents);
		if(!service) 
		{
			service = MetaComponents.initialize(Mallocator.cit);
			editor.services.add(service);
		}

		alias structs = Structs!(Module);
		foreach(s; structs)
		{
			static if(hasAttribute!(s, Component))
			{
				enum hash = HashID(s.stringof).value;
				auto name  = cast(char[])GC.it.allocateRaw(s.stringof.length, 1);
				name[]	   = s.stringof;
				auto mcomp = MetaComponent(cast(string)name, hash);			
				service.add(mcomp);
			}
		}
	}


	__gshared static this()
	{
		import reflection.generation : genFunction;
		genFunction!(initialize_component_bindings)();
	}
}
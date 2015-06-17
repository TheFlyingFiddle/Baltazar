module pluginshared.componentmeta;

struct Component { }
mixin template ComponentBindings(alias Module)
{
	import bridge.core : PluginSetup, IEditor;
	@PluginSetup void initialize_component_bindings(IEditor editor) 
	{
		import util.hash : HashID;
		import util.traits : Structs, hasAttribute;
		import std.traits  : hasMember;
		import pluginshared.data;
		import allocation;
		import bridge.data;

		auto service = editor.services.locate!(MetaComponents);
		if(!service) 
		{
			service = MetaComponents.initialize(Mallocator.cit);
			editor.services.add(service);
		}

		static void* stdload(T)(IEditorState state, uint id, T* store)
		{
			T t = state.proxy!T(id).get();
			*store = t;
			return store;
		}

		static void stdstore(T)(IEditorState state, uint id, T* store)
		{
			auto p = state.proxy!T(id);
			T t = *store;
			p.set(t);
		}

		alias structs = Structs!(Module);
		foreach(s; structs)
		{
			static if(hasAttribute!(s, Component))
			{
				enum hash = HashID(s.stringof).value;
				auto name  = cast(char[])GC.it.allocateRaw(s.stringof.length, 1);
				name[]	   = s.stringof;

				// Create Show Function
				showFunction func;

				static if(hasMember!(s,"show")) 
				{
					func = &s.show;
				} 
				else
				{
					import ui.base, ui.reflection;
					static bool stdshow(T)(ref Gui gui, ref float offset, float width, T* data)
					{
						auto size = gui.typefieldHeight(*data);
						offset -= size + 5;
						return gui.typefield(Rect(5, offset, width, size), *data);
					}
					func = cast(showFunction)&stdshow!s;
				}
			
				auto mcomp = MetaComponent(cast(string)name, hash, s.sizeof, func, cast(loadComponent)&stdload!s, cast(storeComponent)&stdstore!s);
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
module pluginshared.toolmeta;

mixin template ToolBindings(alias Module)
{
	import bridge.core : PluginSetup, IEditor;
	@PluginSetup void initialize_tool_bindings(IEditor editor) 
	{
		import pluginshared.data;
		import allocation;
		import log;

		auto service = editor.services.locate!(MetaTools);
		if(!service) 
		{
			service = MetaTools.initialize(Mallocator.cit);
			editor.services.add(service);
		}

		alias classes = Classes!(Module);
		foreach(c; classes)
		{
			static if(is(c : ITool))
			{
				ITool tool = Mallocator.it.allocate!(c);

				auto name  = cast(char[])Mallocator.it.allocateRaw(tool.name.length, 1);
				name[]	   = tool.name;

				MetaTool mtool = MetaTool(cast(string)name, tool);
				service.add(mtool);
			}
		}
	}

	__gshared static this()
	{
		import reflection.generation : genFunction;
		genFunction!(initialize_tool_bindings)();
	}
}
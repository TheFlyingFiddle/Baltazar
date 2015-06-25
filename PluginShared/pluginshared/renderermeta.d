module pluginshared.renderermeta;

mixin template RendererBindings(alias Module)
{
	import bridge.core : PluginSetup, IEditor;
	@PluginSetup void initialize_renderer_bindings(IEditor editor) 
	{
		import pluginshared.data;
		import allocation;
		import log;
		import util.traits;


		auto service = editor.services.locate!(MetaRenderers);
		if(!service) 
		{
			service = MetaRenderers.initialize(Mallocator.cit);
			editor.services.add(service);
		}

		alias funcs = Functions!(Module);
		foreach(i, func; funcs)
		{
			static if(hasValueAttribute!(funcs[i], WorldRenderer))
			{
				enum vr = getAttribute!(func,WorldRenderer);
				MetaRenderer renderer;
				renderer.name = vr.name.idup;
				renderer.render = &func;

				service.add(renderer);
			}
		}
	}

	__gshared static this()
	{
		import reflection.generation : genFunction;
		genFunction!(initialize_renderer_bindings)();
	}
}
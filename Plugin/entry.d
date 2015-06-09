module entry;

import pluginshared.data;
import pluginshared.components;
import collections.list;
import bridge.core, bridge.data;

@PluginSetup
void initialize(IEditor editor)
{
	import log;
	logInfo("I am great!");

	auto service = editor.services.locate!(SharedDataCont);
	if(!service) 
	{
		import allocation;
		auto s = SharedDataCont.initialize(Mallocator.cit);
		editor.services.locate!(SharedDataCont);
	}

	if(!editor.state.exists(Guid.init, EntitySet))
	{
		editor.state.proxy!(Guid[], EntitySet)(Guid.init).create();
		editor.state.proxy!(Guid[], ArchetypeSet)(Guid.init).create();
	}	
}

import reflection;
enum Filter(T) = true;
mixin GenerateMetaData!(Filter, entry);
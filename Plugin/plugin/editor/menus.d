module plugin.editor.menus;

import bridge.attributes;
import bridge.core;

@MenuItem("FILE.New.Project")
void new_()
{
	auto files   = Editor.services.locate!(IFileFinder);
	auto save    = files.saveProjectPath();
	if(save)
	{
		Editor.save(save);
	}

	Editor.create();

}

@MenuItem("FILE.Open")
void open()
{
	auto files   = Editor.services.locate!(IFileFinder);
	auto path    = files.findOpenProjectPath();
	if(path)
	{
		Editor.open(path);
	}
}


@MenuItem("FILE.Save", KeyCommand(KeyModifiers.control, Key.s))
void save()
{
	auto files = Editor.services.locate!(IFileFinder);
	auto path = files.saveProjectPath();
	if(path)
	{
		Editor.save(path);
	}
}

@MenuItem("FILE.Save As", KeyCommand(KeyModifiers.control | KeyModifiers.shift, Key.s))
void saveAs()
{
	auto files = Editor.services.locate!(IFileFinder);
	auto path = files.findSaveProjectPath();
	if(path)
	{
		Editor.save(path);
	}
}

@MenuItem("FILE.Exit")
void exit()
{
	Editor.close();
}

@MenuItem("EDIT.undo", KeyCommand(KeyModifiers.control, Key.z))
void undo()
{
	auto state = Editor.state();
	state.undo();
}

@MenuItem("EDIT.redo", KeyCommand(KeyModifiers.control | KeyModifiers.shift, Key.z))
void redo()
{
	auto state = Editor.state();
	state.redo();
}

@MenuItem("Game.run", KeyCommand(KeyModifiers.control, Key.g))
void runGame()
{
	save();
	Editor.runGame();
}



import reflection.generation;
enum Filter(T) = true;
mixin GenerateMetaData!(Filter, plugin.editor.menus);
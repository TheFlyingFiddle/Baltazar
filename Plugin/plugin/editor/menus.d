module plugin.editor.menus;

import bridge;
import bridge.core;
import plugin.editor.data;


@MenuItem("File.New.Project")
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

@MenuItem("File.Open")
void open()
{
	auto files   = Editor.services.locate!(IFileFinder);
	auto path    = files.findOpenProjectPath();
	if(path)
	{
		Editor.open(path);
	}
}

@MenuItem("File.Save", KeyCommand(KeyModifiers.control, Key.s))
void save()
{
	auto files = Editor.services.locate!(IFileFinder);
	auto path = files.saveProjectPath();
	if(path)
	{
		Editor.save(path);
	}
}

@MenuItem("File.Save As", KeyCommand(KeyModifiers.control | KeyModifiers.shift, Key.s))
void saveAs()
{
	auto files = Editor.services.locate!(IFileFinder);
	auto path = files.findSaveProjectPath();
	if(path)
	{
		Editor.save(path);
	}
}

@MenuItem("File.Exit")
void exit()
{
	Editor.close();
}

@MenuItem("Edit.undo", KeyCommand(KeyModifiers.control, Key.z))
void undo()
{
	auto doUndo = Editor.services.locate!(DoUndo);
	doUndo.undo();
}

@MenuItem("Edit.redo", KeyCommand(KeyModifiers.control | KeyModifiers.shift, Key.z))
void redo()
{
	auto doUndo = Editor.services.locate!(DoUndo);
	doUndo.redo();
}
module bridge_os;
import bridge.core;
import dialogs;
import std.c.string, std.path;

final class FileFinder : IFileFinder
{
	char[256] buffer;

	this()
	{
		buffer[] = '\0';
	}

	string path() nothrow
	{
		import std.c.string;
		auto len = strlen(buffer.ptr);
		return cast(string)buffer[0 .. len];
	}

	string findOpenProjectPath() nothrow
	{
		if(openFileDialog("Map\0*.sidal\0", buffer[]))
		{
			return path;
		}
		else 
			return null;
	}

	string findSaveProjectPath() nothrow
	{
		if(saveFileDialog("Map\0*.sidal\0", buffer[]))
		{
			auto len = strlen(buffer.ptr);
			if(buffer[0 .. len].extension != ".sidal")
				buffer[len .. len + ".sidal".length + 1] = ".sidal\0"; 

			len = strlen(buffer.ptr);
			
			return cast(string)buffer[0 .. len];
		}
		else 
			return null; 
	}

	string openProjectPath() nothrow
	{
		if(buffer[0] != '\0')
			return path;
		else 
			return findOpenProjectPath();
	}

	string saveProjectPath() nothrow
	{
		if(buffer[0] != '\0')
			return path;
		else 
			return findSaveProjectPath();
	}

	string openPath(string ext)
	{
		if(openFileDialog(ext, buffer[]))
		{

			auto len = strlen(buffer.ptr);
			return cast(string)buffer[0 .. len];
		}

		return null;
	}

	string savePath(string ext)
	{
		if(saveFileDialog(ext, buffer[]))
		{
			auto len = strlen(buffer.ptr);
			return cast(string)buffer[0 .. len];
		}

		return null;
	}
}

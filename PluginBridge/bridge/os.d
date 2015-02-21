module bridge.os;

interface IFileFinder
{
	string findOpenProjectPath() nothrow;
	string openProjectPath() nothrow;

	string findSaveProjectPath() nothrow;
	string saveProjectPath() nothrow;
}
module dialogs;

import core.sys.windows.windows;
import std.c.string;

pragma(lib, "comdlg32");
bool openFileDialog(const(char)[] filterString, char[] result) nothrow
{
	result[0] = '\0';

	OPENFILENAMEA ofn = OPENFILENAMEA.init;
	memset ( &ofn, 0, OPENFILENAMEA.sizeof );

	ofn.lStructSize = OPENFILENAMEA.sizeof;
	ofn.lpstrFilter = filterString.ptr;
	ofn.nFilterIndex = 1;
	ofn.Flags		= 0x00001000;
	ofn.lpstrFile   = result.ptr;
	ofn.nMaxFile    = result.length;

	DWORD len = 256;
	char[256] directory;
	GetCurrentDirectoryA(len, directory.ptr);
	auto res = GetOpenFileNameA(&ofn) != 0;
	SetCurrentDirectoryA(directory.ptr);

	return res;
}

bool saveFileDialog(const(char)[] filterString, char[] result) nothrow
{
	result[0] = '\0';

	OPENFILENAMEA ofn = OPENFILENAMEA.init;
	memset ( &ofn, 0, OPENFILENAMEA.sizeof );

	ofn.lStructSize = OPENFILENAMEA.sizeof;
	ofn.lpstrFilter = filterString.ptr;
	ofn.nFilterIndex = 1;
	ofn.Flags		= 0x00001000;
	ofn.lpstrFile   = result.ptr;
	ofn.nMaxFile    = result.length;


	DWORD len = 256;
	char[256] directory;
	GetCurrentDirectoryA(len, directory.ptr);
	auto res = GetSaveFileNameA(&ofn) != 0;
	SetCurrentDirectoryA(directory.ptr);

	return res;
}
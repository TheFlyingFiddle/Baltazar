module dialogs;

import core.sys.windows.windows;
import std.c.string;

pragma(lib, "comdlg32");

bool openFileDialog(HWND handle, const(char)[] filterString, char[] result)
{
	result[0] = '\0';

	OPENFILENAMEA ofn = OPENFILENAMEA.init;
	memset ( &ofn, 0, OPENFILENAMEA.sizeof );

	ofn.lStructSize = OPENFILENAMEA.sizeof;
	ofn.hwndOwner   = handle;
	ofn.lpstrFilter = filterString.ptr;
	ofn.nFilterIndex = 1;
	ofn.Flags		= 0x00001000;
	ofn.lpstrFile   = result.ptr;
	ofn.nMaxFile    = result.length;

	return GetOpenFileNameA(&ofn) != 0;
}

bool saveFileDialog(HWND handle, const(char)[] filterString, char[] result)
{
	result[0] = '\0';

	OPENFILENAMEA ofn = OPENFILENAMEA.init;
	memset ( &ofn, 0, OPENFILENAMEA.sizeof );

	ofn.lStructSize = OPENFILENAMEA.sizeof;
	ofn.hwndOwner   = handle;
	ofn.lpstrFilter = filterString.ptr;
	ofn.nFilterIndex = 1;
	ofn.Flags		= 0x00001000;
	ofn.lpstrFile   = result.ptr;
	ofn.nMaxFile    = result.length;

	return GetSaveFileNameA(&ofn) != 0;
}
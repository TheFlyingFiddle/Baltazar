import std.stdio;

int main(string[] argv)
{
	Test t;
	t.b = 32;

	writeln(t.getB1, " ", t.getB2, " ", t.getB3);


    writeln("Hello D-World!");
	readln;
    return 0;
}

struct Test
{
	union
	{
		ulong a;
		ubyte b;
	}

	auto getB1()
	{
		return cast(ubyte)(a & 0xFFFF_FFFF_FFFF_FF00);
	}	

	auto getB2()
	{
		return cast(ubyte)(a >> 56 &  0xFFFF_FFFF_FFFF_FF00);
	}


	auto getB3()
	{
		return cast(ubyte)(a << 56 &  0xFFFF_FFFF_FFFF_FF00);
	}
}	

import std.bitmanip;
pragma(msg, 
bitfields!(uint, "Hello", 8, uint, "thirtytwo", 32, uint, "test", 6, uint, "last", 18));
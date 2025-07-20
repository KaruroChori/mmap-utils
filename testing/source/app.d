import std.stdio;

import mmap_utils.vector;

extern(C) void main()
{
	MemMapVector!int qa = MemMapVector!int("./banana.v",100);
	qa[20] = 105;

	for(int i = 0 ; i<30; i++){
		printf("%d ",qa[i]);
	}

	printf("Edit source/app.d to start your project.");
}

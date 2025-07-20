import std.stdio;

import mmap_utils.vector;

extern(C) void main()
{
	{
		MemMapVector!int qa = MemMapVector!int("./tmp/banana.bin",0);
		for(int i = 0 ; i<30; i++){
			qa.pushBack(i);
		}
		qa[20] = 105;

		for(int i = 0 ; i<30; i++){
			printf("%d ",qa[i]);
		}
	}

	printf("\n");

	{
		MemMapVector!int qa = MemMapVector!int(null,0);
		for(int i = 0 ; i<30; i++){
			qa.pushBack(i);
		}
		qa[20] = 105;

		for(int i = 0 ; i<30; i++){
			printf("%d ",qa[i]);
		}
	}

	printf("Edit source/app.d to start your project.");
}

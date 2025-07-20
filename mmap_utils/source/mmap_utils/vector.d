module mmap_utils.vector;

version(Windows)
{
    static assert(0, "This code is POSIX‐only (uses mmap/ftruncate).");
}

import core.stdc.stdio : perror, printf;
import core.stdc.string : memcpy, memset;
import core.stdc.stdlib : malloc, free;
import core.stdc.errno : errno;
import core.stdc.stdint : intptr_t;
import core.sys.posix.sys.mman;

import core.sys.posix.sys.mman : mmap, munmap, PROT_READ, PROT_WRITE, MAP_SHARED, MAP_ANON, MAP_FAILED;

version(linux){
import core.sys.linux.sys.mman : mremap, MAP_HUGETLB, MREMAP_MAYMOVE;
}

//TODO: Add support for the other supporting Unix

import core.sys.posix.fcntl : open, O_RDWR, O_CREAT, O_TRUNC;
import core.sys.posix.unistd : close, ftruncate;

import core.stdc.string : strcmp;

// A simple file‐backed vector in betterC mode
extern (C)
struct MemMapVector(T)
{
    int fd = -1;
    T*  data;
    size_t length;
    size_t capacity;  // in elements

    /// Initialize: open (or create) file and map an initial region
    this(immutable char* path, size_t reserve)
    {
        capacity = reserve==0?1:reserve;
        length   = 0;

        bool anon = strcmp(path,"")==0;

        if(!anon){
            // Open or create the file for read/write; truncate to zero
            fd = open(path, O_RDWR | O_CREAT, 0x1A4 /*0644*/);
            if (fd < 0)
            {
                perror("open");
                assert(false);
            }
        }
        
        // Ensure the file is at least initialCapacity * sizeof(T)
        auto bytes = capacity * T.sizeof;
        if (ftruncate(fd, cast(ulong)bytes) != 0)
        {
            perror("ftruncate");
            close(fd);
            assert(false);
        }

        // mmap the file
        if(capacity != 0) {
            data = cast(T*) mmap(null, bytes,
                            PROT_READ | PROT_WRITE,
                            MAP_SHARED | (anon?MAP_ANON:0),
                            fd, 0);

            if (data == cast(T*)MAP_FAILED)
            {
                perror("mmap");
                printf("%d ...\n",errno);
                close(fd);
                assert(false);
            }
        }

    }

    /// Clean up: unmap and close
    ~this()
    {
        if (data !is null && capacity > 0)
        {
            munmap(data, capacity * T.sizeof);
            data = null;
        }
        if (fd >= 0)
        {
            close(fd);
            fd = -1;
        }
        length = capacity = 0;
    }

    /// Reserve at least newCapacity elements
    int reserve(size_t newCapacity)
    {
        if (newCapacity <= capacity)
            return 0;

        if (fd >=0 ){
            // Extend the underlying file
            auto newBytes = newCapacity * T.sizeof;
            if (ftruncate(fd, cast(ulong)newBytes) != 0)
            {
                perror("ftruncate");
                return -1;
            }

        }

        if(capacity==0){
            capacity = newCapacity;
            data = cast(T*) mmap(null, capacity * T.sizeof,
                            PROT_READ | PROT_WRITE,
                            MAP_SHARED | (fd<0?MAP_ANON:0),
                            fd, 0);

            if (data == cast(T*)MAP_FAILED)
            {
                perror("mmap");
                printf("%d ...\n",errno);
                close(fd);
                assert(false);
            }
        }
        else{
            T* newdata = cast(T*) mremap(data,capacity * T.sizeof, newCapacity * T.sizeof, MREMAP_MAYMOVE);
            if (newdata == MAP_FAILED) {
                perror("mremap");
                destroy(this);
                return -1;
            }
            else{
                data=newdata;
                capacity = newCapacity;
            }
        }
        
        return 0;
    }

    /// Append one element (copy)
    int pushBack(T value)
    {
        // Grow (doubling strategy)
        if (length + 1 > capacity)
        {
            size_t newCap = (capacity == 0) ? 1 : capacity * 2;
            if (reserve(newCap) != 0)
                return -1;
        }
        data[length++] = value;
        return 0;
    }

    /// Indexing
    ref T opIndex(size_t idx) @system
    {
        // No bounds check in betterC
        return data[idx];
    }

    T* ptr() @system { return data; }
}

string GenString(bool fake=true)(string a, string b)
{
    class hellor{
        int a;
    }
    hellor hw;
    string[string] hello = ["red":"quarto","blue":"gmagico"];
    //string name = "John Doe";
    //auto greeting = i"Hello, $(name)";
    return a ~ ", " ~ hello[b];
}

enum int[string] hello = ["red":10,GenString("a","blue"):100];


//mixin(GenString("int a","b;"));

/*
shared static this()
{
    import std.exception : assumeUnique;
    import std.conv : to;

    int[string] temp; // mutable buffer
    foreach (i; 0 .. 10)
    {
        temp[to!string(i)] = i;
    }
    //temp.rehash; // for faster lookups

    hello = assumeUnique(temp);
}
*/


struct cfg_t{
    string name;
    string desc;

    struct field_t{
        bool a;
        int b;
    };

    int w;
    field_t[] fields;

};



// Example usage
int test()
{
    enum cfg_t txt = {
        name : "hello",
        w: 22,
        fields: [
            {0,0}
        ]
    };

    auto w = q{
        hello world $(12) {
            int main()
        }
    };


    MemMapVector!int vec = MemMapVector!int("test.dat", 4);

    //hello["ss"]=4;
    string banana = "dd";
    printf("%d\n",hello["red"]);

    // Push 10 integers
    foreach (i; 0 .. 10)
    {
        if (vec.pushBack(i) != 0)
        {
            return 1;
        }
    }

    // Print them
    foreach (i; 0 .. vec.length)
    {
        // use printf from core.stdc.stdio
        printf("vec[%d] = %d\n", i, vec[i]);
    }

    return 0;
}

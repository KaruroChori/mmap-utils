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

import core.sys.posix.sys.types;
import core.sys.posix.sys.stat: fstat, stat_t;

// A simple file‐backed vector in betterC mode
extern (C)
struct MemMapVector(T)
{    
    struct State{
        size_t length;
        size_t capacity;  // in elements T
    }

    private: 
    
    State* state = null;
    int fd = -1;
    bool preserve;

    @property ref size_t length(){
        assert(state!=null);
        return state.length;
    }

    @property ref size_t capacity(){
        assert(state!=null);
        return state.capacity;
    }

    @property T* data(){
        assert(state!=null);
        return cast(T*)( cast(ubyte*)(state) + State.sizeof + ((State.sizeof%T.sizeof==0)?0:(T.sizeof-State.sizeof%T.sizeof)));
    }

    public:
    
    @property ref const(size_t) length() const{
        assert(state!=null);
        return state.length;
    }

    @property ref const(size_t) capacity() const{
        assert(state!=null);
        return state.capacity;
    }

    /// Initialize: open (or create) file and map an initial region
    this(immutable char* path, size_t initialCapacity, bool preserve=false)
    {
        bool anon = path==cast(char*)null;
        this.preserve=preserve;
        
        if(!anon){
            // Open or create the file for read/write; truncate to zero
            fd = open(path, O_RDWR | O_CREAT, 0x1A4 /*0644*/);
            if (fd < 0)
            {
                perror("open");
                assert(false);
            }
        }

        reserve(initialCapacity);
    }

    /// Clean up: unmap and close
    ~this()
    {
        if (state !is null)
        {
            munmap(state, fullSize(capacity));
            state = null;
        }
        if (fd >= 0)
        {
            close(fd);
            fd = -1;
        }
    }

    size_t fullSize(size_t newCapacity){
        return State.sizeof + ((State.sizeof%T.sizeof==0)?0:(T.sizeof-State.sizeof%T.sizeof)) + newCapacity*T.sizeof;
    }

    private int first_reserve(size_t newCapacity)
    {
        if(preserve==true && fd>=0){

            long getSizeByStat()
            {
                stat_t st;
                if (fstat(fd, &st) != 0)
                {
                    perror("stat");
                    return -1;
                }
                return cast(long)st.st_size;
            }

            state = cast(State*) mmap(null, getSizeByStat(),
                PROT_READ | PROT_WRITE,
                MAP_SHARED | (fd<0?MAP_ANON:0),
                fd, 0);

            if (state == cast(State*)MAP_FAILED)
            {
                perror("mmap");
                close(fd);
                return -1;
            }
            return 0;
        }

        if (fd >=0 ){
            // Extend the underlying file
            auto newBytes = fullSize(newCapacity);
            if (ftruncate(fd, cast(ulong)newBytes) != 0)
            {
                perror("ftruncate");
                return -1;
            }

        }
        
        state = cast(State*) mmap(null, fullSize(newCapacity),
                        PROT_READ | PROT_WRITE,
                        MAP_SHARED | (fd<0?MAP_ANON:0),
                        fd, 0);

        if (state == cast(State*)MAP_FAILED)
        {
            perror("mmap");
            close(fd);
            return -1;
        }

        capacity = newCapacity;
        length   = 0; 
               
        return 0;
    }

    /// Reserve at least newCapacity elements
    int reserve(size_t newCapacity)
    {
        if(state==null){
            State tmp = {0,0};
            state=&tmp;
            return first_reserve(newCapacity);
        }

        auto newBytes = fullSize(newCapacity);

        if (fd >=0 ){
            // Extend the underlying file
            if (ftruncate(fd, cast(ulong)newBytes) != 0)
            {
                perror("ftruncate");
                return -1;
            }

        }
        State* newState = cast(State*) mremap(state,fullSize(capacity), newBytes, MREMAP_MAYMOVE);
        if (newState == MAP_FAILED) {
            perror("mremap");
            destroy(this);
            return -1;
        }
        else{
            state = newState;
            capacity = newCapacity;
        }
        
        return 0;
    }

    /// Append one element (copy)
    int pushBack(ref const(T) value)
    {
        printf("%ld %ld\n", length, capacity);
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
        assert(idx<length);
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

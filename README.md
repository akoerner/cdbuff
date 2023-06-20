# cdbuff
Your grandpa's cd command

cdbuff is a simple command line tool to enhance the 'cd' command written in bash
to save and recall paths by name. It can be useful if you have multiple projects
where you can store the path of each project workspace with cdbuff in "named 
buffers".

## Getting started
1. clone the repo
```bash
git clone https://github.com/akoerner/cdbuff.git
```

2. in your bashrc or zshrc source cdbuff
```bash
...
source path/to/cdbuff/cdbuff
...
```
3. Set the primary buffer:
```bash
cd to/some/interesting/path
cdbuff -s
```

```bash
cdbuff -s
Setting cd buffer: (primary): /home/cdbuff/this/is/an/interesting/path
```

4. Later return to the primary buffer path:
```bash
cdbuff
```
```bash
pwd
/home/cdbuff
cdbuff
Changing directory to: primary@/home/cdbuff/this/is/an/interesting/path
/home/cdbuff/this/is/an/interesting/path
pwd
/home/cdbuff/this/is/an/interesting/path
```


#### List available buffers
The following command will return a list of all defined cdbuff buffers:
```bash
cdbuff -l
```

#### Setting a named cd buffer
1. cd to a path you want to store
2. invoke cdbuff with -s for set and -b to define the buffer:
```bash
cd some/path
cdbuff -s -b special_path
Setting cd buffer: (special_path): /home/cdbuff/some/path

```

#### Returning to a named buffer
You have two options to return to a previously named buffer. The first is to 
simply use the buffer name:
```bash
cdbuff -b special_path
```
The second option is to use the buffer index:
1.
```bash
cdbuff -l
Named buffers:
    0: (primary)  : /home/cdbuff/this/is/an/interesting/path         => 'cdbuff primary' or 'cdbuff 0' or 'cdbuff -b primary'                        
    1: (special_path): /home/cdbuff/some/path                        => 'cdbuff special_path' or 'cdbuff 1' or 'cdbuff -b special_path'              
    buffer file: /home/cdbuff/.cdbuff
```

2. Once you know the index you can always use it to refer to the buffer:
```bash
cdbuff 1
Changing directory to: special_path@/home/cdbuff/some/path
/home/cdbuff/some/path
```

**Note:** Indexes are dynamic and will change with any modification of the named
buffers. Be sure to use "cdbuff -l" to verify the new indexes.

#### Deleting a named buffer
Using the '-d' flag will delete the named buffer.
The following command will delete the "special_path" buffer which in this
example is index '1'
```bash
cdbuff -d -b 1
Deleted: special_path@/home/cdbuff/some/path
```
You can also of course refer to the buffer by name:
```bash
cdbuff -d -b special_path 
Deleted: special_path@/home/cdbuff/some/path
```
Note that indexes are dynamic and subject to change whenever adding or deleting
buffers so always double check the index after updating the buffers with '-l'


#### cdbuff buffer file
The cdbuff buffer file is $HOME/.cdbuff by default

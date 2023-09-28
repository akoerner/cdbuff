# cdbuff
Your grandpa's cd command

cdbuff is a simple command line tool to enhance the 'cd' command written in 
bash. It can be useful if you have multiple projects allowing you to store or 
recall paths by name or index. 

cdbuff is meant to be used interactively to quickly change your working
directory to and from frequently used directories.

## Named Buffers
With cdbuff you can save and restore paths by assigning arbitrary names to them.

## Rolling Indexed Buffers
cdbuff has a circular buffer similar to vim.  Every path stored with '-s' will
appear in the indexed buffers. With each new path the index of the previous is 
incremented.

## Getting started
1. clone the repo
```bash
git clone https://github.com/akoerner/cdbuff.git
```

2. In your .bashrc or .zshrc source cdbuff:
```bash
source path/to/cdbuff/cdbuff
alias cb=cdbuff
```
3. Set the primary buffer:
```bash
cd to/some/interesting/path
cdbuff -s
Setting cd buffer: (primary): /home/cdbuff/to/some/interesting/path
```

Later you can recall and change back to that directory stored in the `primary`
buffer by invoking `cdbuff` with no flags: 
```bash
cdbuff
Changing directory to: primary@/home/cdbuff/to/some/interesting/path
/home/cdbuff/to/some/interesting/path
```

#### List available buffers
The following command will return a list of all defined cdbuff buffers:
```bash
cdbuff -l
```

#### Setting a named cd buffer
1. cd to a path you want to store
2. invoke cdbuff with `-s`:
```bash
cd some/path
cdbuff -s special_path
Setting cd buffer: (special_path): /home/cdbuff/some/path
```

#### Returning to a named buffer
You have two options to return to a previously named buffer. The first is to 
simply use the buffer name:
```bash
cdbuff special_path
Changing directory to: special_path@/home/cdbuff/some/path
/home/cdbuff/some/path
```

The second option is to use the buffer index:
1.
```bash
cdbuff -l
```
```bash
Numerical buffers:
    9:
    8:
    7:
    6:
    5:
    4:
    3:
    2: 
    1:
    0: /home/cdbuff/some/path

Named buffers:
   (special_path): /home/cdbuff/some/path

    buffer file: /home/cdbuff/.cdbuff
```

> **ℹ️INFO:**
> The buffer index will automatically advance with each invocation of `cdbuff -s`

2. Once you know the index you can always use it to refer to the buffer:
```bash
cdbuff 0 
Changing directory to: special_path@/home/cdbuff/some/path
/home/cdbuff/some/path
```

#### Deleting a named buffer
Using the '-d' flag will delete a buffer.
The following command will delete numerical buffer which in this
example is index '0':
```bash
cdbuff -d 0
Deleted: 0@/home/cdbuff/some/path
```
You can also delete named buffers:
```bash
cdbuff -d special_path 
Deleted: special_path@/home/cdbuff/some/path
```

#### cdbuff buffer file
The cdbuff buffer file is $HOME/.cdbuff by default

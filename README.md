# cdbuff
Your grandpa's cd command

cdbuff is a simple command line tool to enhance the 'cd' command written in 
bash. It can be useful if you have multiple projects allowing you to store or 
recall paths by name or index. 

cdbuff is meant to be used interactively to quickly change your working
directory to and from frequently used directories.

## Named Registers
With cdbuff you can save and restore paths to registers by assigning arbitrary 
names to them.

## Rolling Indexed Registers
cdbuff has a circular registers indexed registers [0-9] similar to vim.  Every 
path stored with '-s' will pushed into the indexed registers with the most 
recent being assigned to register `0`. The previous path that was stored in 
register `0` will be pushed to register `1` and so on.

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
3. Set the primary register:
```bash
cd to/some/interesting/path
cdbuff -s
Setting cd register: (primary): /home/cdbuff/to/some/interesting/path
```

Later you can recall and change back to that directory stored in the `primary`
register by invoking `cdbuff` with no flags: 
```bash
cdbuff
Changing directory to: primary@/home/cdbuff/to/some/interesting/path
/home/cdbuff/to/some/interesting/path
Setting cd register: (primary): /home/cdbuff/this/is/an/interesting/path
```

#### List available registers
The following command will return a list of all defined cdbuff registers:
```bash
cdbuff -l
```

#### Setting a named register
1. cd to a path you want to store
2. invoke cdbuff with `-s`:
```bash
cd some/path
cdbuff -s special_path
Setting cd register: (special_path): /home/cdbuff/some/path
```

#### Returning to a named register
You have two options to return to a previously named register. The first is to 
simply use the register name:
```bash
cdbuff special_path
Changing directory to: special_path@/home/cdbuff/some/path
/home/cdbuff/some/path
```

The second option is to use the register index:
1.
```bash
cdbuff -l
```
```bash
Numerical register:
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

Named register:
   (special_path): /home/cdbuff/some/path

    register file: /home/cdbuff/.cdbuff
```

> **ℹ️INFO:**
> The register index will automatically advance with each invocation of `cdbuff -s`

2. Once you know the index you can always use it to refer to the register:
```bash
cdbuff 0 
Changing directory to: special_path@/home/cdbuff/some/path
/home/cdbuff/some/path
```

#### Deleting a named register
Using the '-d' flag will delete a register.
The following command will delete numerical register #0:
```bash
cdbuff -d 0
Deleted: 0@/home/cdbuff/some/path
```
You can also delete named register:
```bash
cdbuff -d special_path 
Deleted: special_path@/home/cdbuff/some/path
```

#### cdbuff register file
The cdbuff register file is $HOME/.cdbuff by default

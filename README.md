# Your Grandpa's `cd` Command

`cdbuff` is a simple command-line tool designed to enhance the functionality of the `cd` command in Bash. It is particularly useful if you work on multiple projects, allowing you to store and recall paths by name or index.

cdbuff is intended for interactive use, enabling you to quickly switch between frequently used directories.


## Named Registers
With `cdbuff` you can save and restore paths to registers by assigning arbitrary names to them.

## Rolling Indexed Registers
`cdbuff` features a circular buffer/register system with indexed registers [0-9], similar to Vim.
Every path stored using the `-s` option is pushed into the indexed registers, with the most recent
path assigned to register `0`. The previous path in register `0` is then shifted to register `1`, 
and so on, with older paths cascading through the remaining registers.


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
cb -s
Setting cd register: (primary): /home/cdbuff/to/some/interesting/path
```

Later you can recall and change back to that directory stored in the `primary`
register by invoking `cdbuff` with no flags: 
```bash
cb
Changing directory to: primary@/home/cdbuff/to/some/interesting/path
/home/cdbuff/to/some/interesting/path
```

#### List available registers
The following command will return a list of all defined cdbuff registers:
```bash
cb -l
```

#### Setting a named register
1. cd to a path you want to store
2. invoke cdbuff with `-s`:
```bash
cd some/path
cb -s special_path
Setting cd register: (special_path): /home/cdbuff/some/path
```

#### Returning to a named register
You have two options to return to a previously named register. The first is to 
simply use the register name:
```bash
cb special_path
Changing directory to: special_path@/home/cdbuff/some/path
/home/cdbuff/some/path
```

The second option is to use the register index:
1.
```bash
cb -l
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
> The register index will automatically advance with each invocation of `cb -s`

2. Once you know the index you can always use it to refer to the register:
```bash
cb 0 
Changing directory to: 0/home/cdbuff/some/path
/home/cdbuff/some/path
```

#### Deleting a named register
Using the '-d' flag will delete a register.
The following command will delete numerical register #0:
```bash
cb -d 0
Deleted: 0@/home/cdbuff/some/path
```
You can also delete named register:
```bash
cb -d special_path 
Deleted: special_path@/home/cdbuff/some/path
```

#### cdbuff register file
The cdbuff register file is: `$home/.cdbuff` by default

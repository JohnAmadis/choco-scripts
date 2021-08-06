![Choco-Technologies Logo](https://choco-technologies.com/Logo-Long-NoBG-Black-Small.png)


# Choco-Scripts

The **Choco-Scripts** is a `bash` framework that speeds up scripts development. It is very easy to install and requires only `wget` to start working. 

You can use the following command to install it in your enviroment:


```bash
# This line installs wget tool - you don't need to use it if you already have it
sudo apt-get update && apt-get install -y wget

# This downloads an installation script and run it 
wget -O - https://release.choco-technologies.com/scripts/install-choco-scripts.sh | bash
```

Once the scripts are installed, they are auto-loaded on bash start and you can start using it. To import it in your script, just add the following line into your project:


``bash 
source $(getChocoScriptsPath)
``
***
**NOTE:**

*Please remember that just after installation you have to restart bash to make the command `getChocoScriptsPath` work. You can do this by using command `bash`.*



**You should see the following message:**


```bash
root@76afe4802bf7:/# bash
Hello, Choco scripts are installed in version 1.0.5 in the path /root/.choco-scripts
Please use command source $(getChocoScriptsPath) to import it in your project
root@76afe4802bf7:/#

```

***

## Your first hello-world with Choco-Scripts

*You can create a new **choco-scripts** based application in 2 ways:*

- by using `template.sh` file
- by using `createChocoScript` command

### Usage of template.sh file

To create your first **Choco-Scripts** "Hello World" program use the `template.sh` file:

```bash
# The function copies the template into current path
cp ~/.choco-scripts/template.sh myscript.sh
```

Then edit the `myscript.sh` file in your favorite bash editor. Find the following code inside:


```bash
#
#   The function prepares a framework script to work
#
function prepareScript()
{
    defineScript "$0" "My hello-world script based on choco-scripts framework in version $(cat $CHOCO_SCRIPTS_DIR/version)"
    
    addCommandLineOptionalArgument EXAMPLE_ARGUMENT "-s|--string" "not_empty_string" "Example argument to be parsed from command line arguments" "This is my message from command line argument"
    
    parseCommandLineArguments "$@"
}
```

You can change here the script description and command line arguments. To understand it better it is good to run a `--help` first:

```bash 

root@76afe4802bf7:/# /tmp/myscript.sh --help
Hello, Choco scripts are installed in version 1.0.5 in the path /root/.choco-scripts
Please use command source $(getChocoScriptsPath) to import it in your project
Using choco-scripts from path /root/.choco-scripts in version 1.0.5
[ VERIFICATION ] Directory '/tmp' exists?   
=======================================================================================
                                       HELP                                              
=======================================================================================

The script '/tmp/myscript.sh'

My hello-world script based on choco-scripts framework in version 1.0.5 

  To see the help please use: 
	/tmp/myscript.sh --help
  Usage: 
	/tmp/myscript.sh [--install-required-tool=<value>] [--install-all-required] [--print-required-tools] [--open-browser=<value>] [--curl-output-file=<value>] [--verbose] [--non-interactive] [-s|--string=<value>] 


      where:

            --install-required-tool=*
                       Argument name: __TOOL_TO_INSTALL
                       Argument type: options
                       Type description: 

                                 This argument type allows for choosing only from predefined list of supported values

                       Default value: realpath
                       Value description: 

                                 You can use this option to install tool required by this script

                       Supported values: 

                                 realpath wget unzip sudo htpasswd php parted jq curl

                       Example of usage: 

                                 /tmp/myscript.sh --install-required-tool=realpath

            -s=*,--string=*
                       Argument name: EXAMPLE_ARGUMENT
                       Argument type: not_empty_string
                       Type description: 

                                 This type of argument allows for passing strings, but the string cannot be empty

                       Default value: This is my message from command line argument
                       Value description: 

                                 Example argument to be parsed from command line arguments

                       Example of usage: 

                                 /tmp/myscript.sh --string="some_string"
                             or
                                 /tmp/myscript.sh -s="some_string"

```

As you can see the framework auto-generated the `--help` message for the script


## License

The project is published under **MIT** license.  

*Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:*

*The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.*

*THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.*

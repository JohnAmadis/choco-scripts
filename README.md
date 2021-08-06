![Choco-Technologies Logo](https://choco-technologies.com/Logo-Long-NoBG-Black-Small.png)


# Choco-Scripts

The **Choco-Scripts** is a `bash` framework that speeds up scripts development. It is very easy to install and requires only `wget` to start working. 

You can use the following command to install it in your environemnt:


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


## License

The project is published under **MIT** license.  

*Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:*

*The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.*

*THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.*

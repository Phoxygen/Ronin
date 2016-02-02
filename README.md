Welcome to`Ronin` OS!
===================

What is `Ronin`?
-------------------
It's [FirefoxOS](https://www.mozilla.org/fr/firefox/os/2.0) for desktop: an OS built on web & Mozilla's technologies.


Sounds great, can I try it?
-----------------------

We will soon build a ready to use iso file so that everyone can test it.

But if you have a Debian/Ubuntu based distribution you can play with it already. 

add to your sources.list:

```
deb http://sumo.phoxygen.com trusty main
```
then
```
apt-get install ronin wetty
```

or you can:

* Download a .deb package: http://dl.phoxygen.com/ronin-latest.deb and http://dl.phoxygen.com/wetty-latest.deb
* Before installing make sure you have `nodejs` and `npm` packages installed, and a symlink from `/usr/bin/node` to `/usr/bin/nodejs`
* `dpkg -i ronin-os-latest.deb` (followed by `apt-get install -f` if it complains about missing dependencies)
* You can then launch it in a windowed mode using:
```
$ Xephyr :5&
$ DISPLAY=:5 /opt/b2g/session.sh
```
Or in fullscreen using:
```
startx /opt/b2g/session.sh -- :5
```

Where's the code?
-----------------
The code is splitted in 3 git repositories:
* [Ronin](https://github.com/Phoxygen/Ronin): holds the scripts needed to build the project
* [gaia (`ronin` branch)](https://github.com/Phoxygen/gaia): contains the UI
* [gecko-dev (`ronin` branch as well)](https://github.com/Phoxygen/gecko-dev): is the core of the project.

How to build?
--------------
```
$ git clone https://github.com/Phoxygen/Ronin
$ cd Ronin
$ make build
```
You can then launch `Ronin` in a window:
```
$ make run
```

Or build your own .deb package:

```
$ make package
```

Credits
------
This work has its roots in a old project which can be found at [https://github.com/fabricedesre/b2gian]

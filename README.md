# docker-dev-scripts
Miscellaneous scripts to quickly set-up dockerized development environments.

## > Basic usage:
* clone the project with:
```
git clone https://github.com/aljazmc/docker-scripts
```
* move to the desired subdirectory:
```
cd node-dev
```
* download and setup everytihng necessary with:
```
./project.sh start
```
* after use you can clean-up with: 
```
./project.sh clean
```

## > Requirements:

* GNU/Linux operating system
* docker with docker compose plugin

## > Examples:
```
gcc-dev:
  "./project.sh start" ## 1.) Download gcc container,
                       ## 2.) create main.c file,
                       ## 3.) print environment variables,
                       ## 4.) compile main.c file,
                       ## 5.) and run main program.

  "./project.sh clean" ## Stop containers, remove docker images,
                       ## remove docker-compose.yml and
                       ## main and main.c files.
```
```
go-dev:
  "./project.sh start" ## 1.) Download go container,
                       ## 2.) create main.go file and .cache dir,
                       ## 3.) print environment variables,
                       ## 4.) compile main.go file,
                       ## 5.) and run the main program.

  "./project.sh clean" ## Stop containers, remove docker images,
                       ## remove docker-compose.yml, .cache and
                       ## main and main.go files.
```
```
haskell-dev:
  "./project.sh start" ## 1.) Download haskell container,
                       ## 2.) create helloworld.hs file,
                       ## 3.) print environment variables,
                       ## 4.) compile helloworld.hs file,
                       ## 5.) and run the helloworld program.

  "./project.sh clean" ## Stop containers, remove docker images,
                       ## remove docker-compose.yml and
                       ## helloworld files.
```
```
heapsio-dev:
  "./project.sh start" ## 1.) Download haxe container and build heapsio,
                       ## 2.) create Main.hx file in src/,
                       ## 3.) print environment variables,
                       ## 4.) compile Main.hx file with haxe,
                       ## 5.) and run the hello.hl program.

  "./project.sh clean" ## Stop containers, remove docker images,
                       ## remove docker-compose.yml and
                       ## really a lot of other files.
```
```
java-dev:
  "./project.sh start" ## 1.) Download eclipse-temurin container,
                       ## 2.) create HelloWorld.java file,
                       ## 3.) print environment variables,
                       ## 4.) compile HelloWorld.java file, and
                       ## 5.) run HelloWorld program.

  "./project.sh clean" ## Stop containers, remove docker images,
                       ## remove docker-compose.yml and
                       ## HelloWorld files.
```
```
node-dev:
  "./project.sh start" ## 1.) Download node container,
                       ## 2.) initialize a project (in interactive mode)
                       ## or install packages from package.json if it
                       ## exists and
                       ## 3.) print environment variables.

  "./project.sh clean" ## Stop containers, remove docker images
                       ## and remove installation directories.
```
```
ocaml-dev:
  "./project.sh start" ## 1.) Download ocaml container,
                       ## 2.) install a compiler,
                       ## 3.) initialize a project
                       ## 4.) build helloworld and
                       ## 5.) execute helloworld.

  "./project.sh clean" ## Stop containers, remove docker images
                       ## and remove installation directories.
```
```
python-dev:
  "./project.sh start" ## 1.) Download python container,
                       ## 2.) create hello.py file,
                       ## 3.) print environment variables,
                       ## 4.) compile hello.py and
                       ## 5.) run compiled code.

  "./project.sh clean" ## Stop containers, remove docker images,
                       ## remove docker-compose.yml, __pycache__
                       ## and hello.py files.
```
```
rust-dev:
  "./project.sh start" ## 1.) Download rust container,
                       ## 2.) create hello.rs file,
                       ## 3.) print environment variables,
                       ## 4.) compile hello.rs and
                       ## 5.) run compiled code.

  "./project.sh clean" ## Stop containers, remove docker images,
                       ## remove docker-compose.yml, hello
                       ## and hello.rs files.
```
```
wordpress-dev:
  "./project.sh start" ## 1.) Download composer, database, wordpress, node,
                       ## 2.) and php{unit,myadmin,cs,cbf} containers,
                       ## 2.) generate partial file structure for a theme,
                       ## 3.) and start wordpress.

  "./project.sh clean" ## Stop containers, remove docker images,
                       ## remove generated files and dirs except configs
                       ## and theme files.
```

## > LICENSE: [MIT](https://github.com/aljazmc/docker-scripts/blob/main/LICENSE)

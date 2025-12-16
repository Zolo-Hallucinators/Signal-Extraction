# Setting up venv

### Creating & Activating the environment
1. Open Terminal
2. Switch to src: `cd src`
3. Creating the environment:
    - Windows: `python -m venv env`
    - Mac: `python3 -m venv env`
    - Here `env` is the environment name
4. Activate the virtual environment:
    - Windows: `env\Scripts\activate.bat` or `env\Scripts\activate` (only this worked)
    - Mac: `source env/bin/activate`
    - Once you hit enter you will see the next command prefixing with the environment name `env`

### Deacivating the environment:
1. For both Mac & Windows: `deactivate`

### [IMP] Re-Activating the environment:
1. Open Terminal
2. Switch to src: `cd src`
3. Activate the virtual environment:
    - Windows: ~~`env\Scripts\activate.bat`~~ or `env\Scripts\activate` (only this worked)
    - Mac: `source env/bin/activate`
    - Once you hit enter you will see the next command prefixing with the environment name `env`

### To check existing packages:
1. Perform `pip list`

### [IMP] To freeze installed dependences:
1. Switch to root directory: `cd ..`
2. Perform `pip freeze > requirements.txt`, this will update our main `requirements.txt`. (Recommended when you have come accross a new package so that everyone can install in their own `env` as well)

### [IMP] To install from requirements.txt
1. Create & active your `env` as mentioned above
2. Run `pip install -r requirements.txt`
    - `-r` means install from a file.

### To delete an env:
- Just right click and delete
- or `rm -r env`

### [IMP] To completely uninstall & re-install:
- Perform: `pip freeze | xargs pip uninstall -y` [Worked only in Git Bash]-> to freeze and uninstall frozen items.
- Reinstall: `pip install -r requirements.txt`

### References used:
- Link: https://www.youtube.com/watch?v=Y21OR1OPC9A.
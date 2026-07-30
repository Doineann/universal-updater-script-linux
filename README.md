# Universal Updater

This updater provides a small, self‑contained mechanism to update any application from GitHub releases, direct download URLs, or custom version sources. It is supposed to be generic, portable, and easy to use for any kind of application.

## Installation steps

### 1. Clone or Subtree this project under your application folder

**clone:**

```bash
git clone "https://github.com/doineann/universal-updater-script-linux.git" updater
```

or -recommended- a **subtree:** if that folder is already a git repository:

```bash
git subtree add --prefix "updater" "https://github.com/doineann/universal-updater-script-linux.git" main --squash
```

### 2. Verify folder structure

Your application folder should have the following structure and/or files:

```
/                               -> root folder of your application
|-updater/                      -> a clone or subtree of this repository
  |-updater.sh                  -> universal updater script
  |-README.md                   -> this file
  |-subtree-update.sh           -> script for updating the updater itself
  |-generic/                    -> directory containing scripts used by updater.sh
  |-app-root/                   -> files intended for your application root folder
   |-config-updater.ini         -> template example config
   |-update.sh                  -> wrapper update script (will source the local config and run ./updater/updater.sh)
|-start.sh                      -> (OPTIONAL) custom script to start the application
|-stop.sh                       -> (OPTIONAL) custom script to stop the application
|-pre-install.sh                -> (OPTIONAL) custom script to run pre-install/pre-update
|-post-install.sh               -> (OPTIONAL) custom script to run post-install/pre-update 
```

### 3. Copy the content of `./updater/app-root` to the root of your application folder

Your app’s root folder should contain a copy of the files under `./updater/app-root`. It contains:

 - a template/example `config-updater.ini` file, that you will need to modify in the next step.
 - a wrapper `update.sh` script.

The main `updater` logic lives inside `./updater/updater.sh`. 
The `update.sh` script just provides a means to load your local config and run the actual updater.

From inside your app’s root folder (`./` in the example above), run:

```bash
cp ./updater/app-root/config-updater.ini ./config-updater.ini
cp ./updater/app-root/update.sh ./update.sh
```

### 4. Modify `config-updater.ini` according to the needs of your application

Edit `./config-updater.ini` to match your application's needs. For more information the explanations inside the template/example config itself.

### 5. Done

You should be good to go now.

In some cases your application might need/benefit from having extra some hooked scripts, for example: 

- START and STOP scripts (`start.sh` and `stop.sh`). The Updater will use these to stop and (re-)start the application.
- PRE or POST update scripts (`pre-update.sh` and `post-update.sh`). The Updater will run these before and after an update.

## Running the Updater

Simply run:

```bash
./update.sh
```

The `update.sh` is a wrapper script:

```
#!/usr/bin/env bash
set -e

# Load the local config
source ./config-updater.ini

# Run the universal updater
bash updater/updater.sh
```

It will 'source' the local config first and then call the Updater: `./updater/updater.sh`.

The Updater will:

- detect the installed version (or will detect nothing or no `version.txt` file to be there)
- fetch the latest version
- determines if an update is needed: 
  - nothing found? -> update!
  - latest version different than the version in `version.txt`? -> update!
- stop the application if running, using `stop.sh` (OPTIONAL)
- back up the old version (OPTIONAL)
- runs `pre-update.sh` script (OPTIONAL)
- download + extracts the new version/update
- runs `post-update.sh` script (OPTIONAL)
- restart the app if it was running before, using `start.sh`(OPTIONAL)

---

## Updating the Updater Itself (Git Subtree)

The Updater is designed to be 'embedded' inside an application folder, which might be a git repository as well.

To keep it updated, use a **git subtree**, which allows you to pull updates from the upstream updater repository.

You can either do this manually: 

```bash 
git subtree pull --prefix updater "https://github.com/doineann/universal-updater-script-linux.git" main --squash
```

or use the provided script, run like this:

```bash
./updater/subtree-update.sh
```
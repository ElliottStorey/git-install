
# ElliottStorey/git-install
Home of the script that lives at `ElliottStorey/git-install`!

The purpose of the install script is for a convenience for quickly
installing the latest Git releases on the supported linux
distros. It is not recommended to depend on this script for deployment
to production systems. For more thorough instructions for installing
on the supported distros, see the [install
instructions](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git).

This repository is solely maintained by Elliott Storey.

## Usage:

From `ElliottStorey/git-install`:
```shell
curl -fsSL https://raw.githubusercontent.com/ElliottStorey/git-install/main/install.sh -o get-git.sh
sh get-git.sh
```

To run with `--dry-run` to see what changes will be made:
```shell
sh get-git.sh --dry-run
```

From the source repo (This will install latest from the `stable` channel):
```shell
sh install.sh
```

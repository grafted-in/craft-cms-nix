# [Nix](https://nixos.org/nix/) Setup for [Craft CMS](https://craftcms.com/) Demo - [Happy Lager](https://github.com/pixelandtonic/HappyLager)

This repository contains everything necessary to test and deploy fully operational web servers for [Craft CMS](https://craftcms.com/) sites. For demonstration the code is configured to run the [Happy Lager](https://github.com/pixelandtonic/HappyLager) example site.

This setup uses the powerful [Nix](https://nixos.org/nix/) package management system and its accompanying toolset:

  - [NixOps](https://nixos.org/nixops/) for deployments
  - [NixOS](https://nixos.org/) as the Linux-based server OS

**Note:** Nix does not support Windows. If you're on Windows, you'll need to run this from within a Virtual Machine (VM).

With this setup, you can easily deploy your site to one or more servers with minimal effort. You can (and should) also deploy to local [VirtualBox](https://www.virtualbox.org/) virtual machines. And, you can even use the Nix packages to install the site directly on your local host.


## Requirements

  1. First install [Nix](https://nixos.org/nix/). It is not invasive and can be removed easily if you change your mind.

  2. Deployments are done with [NixOps](https://nixos.org/nixops/). You can install `nixops` with `nix` by running `nix-env -i nixops`. However, you don't need to because this repository has a `deploy/manage` script that you'll use which will run `nixops` tasks for you.

  3. Install [VirtualBox](https://www.virtualbox.org/) in order to test your server deployments.

  4. If you plan to deploy to a real server, you will likely need to keep secrets in this repository. That will require installing [git-crypt](https://www.agwa.name/projects/git-crypt/) and setting it up. See `SETUP-SECRETS.md` for information on that.


## Deploying to VirtualBox

Create a VirtualBox deployment:

  1. `deploy/manage create -d vbox '<logical.nix>' '<physical.vbox.nix>'`
  2. `deploy/manage deploy -d vbox`

**Notes:**

  * `nixops` deployments can sometimes be finicky. If something hangs or fails, try running it again. It is a very deterministic system so this should not be a problem.
  * Run `deploy/manage --help` to see all options (this is just `nixops` underneath).
  * If you would like to save this deployment in the repository, run `deploy/manage export -d vbox > deploy/vbox.nixops-exported`. This will cause the `manage` script to keep the file up-to-date so you can commit it.

You should then be able to open the IP of the VM in your browser and test it. If you don't know the IP, run `deploy/manage info -d vbox`.


## Deploying to Real Servers

With this setup you can deploy to any PaaS/IaaS service supported by `nixops`. Right now we only have prewritten configuration for Google Cloud Compute's [Google Compute Engine (GCE)](https://cloud.google.com/compute/). We plan to add more (such as AWS) in the future. If you want to do it yourself and understand Nix, the work to add this configuration is minimal. Pull requests welcome!

Read `DEPLOY-GCE.md` to learn about GCE deployments.


## Acknowledgements

  * The server setup is highly influenced by
    * https://github.com/nystudio107/nginx-craft
    * https://github.com/nystudio107/craft-scripts
    * https://nystudio107.com/blog/hardening-craft-cms-permissions
  * Special thanks to @khalwat

# Nerdio Manager scripts

> [!CAUTION]
> This code is provided as-is, without warranty or support of any kind.

## 🖥️ Scripted Actions - /actions

PowerShell scripts for integration with [Scripted Actions in Nerdio Manager](https://nmehelp.getnerdio.com/hc/en-us/articles/26124327585421-Scripted-Actions-Overview).

These scripts can be added to your Nerdio Manager install by specifying the paths below to add individual directories:

* `/actions/core` - scripts for building a Windows 10/11 pooled desktop (single session or multi-session). Can be used to build an image or run against already deployed session hosts
* `/actions/3rdparty` - scripts for installing 3rd party applications
* `/actions/tweaks` - scripts for implementing specific configurations and tweaks for gold images or session hosts
* `/actions/optimise` - scripts to optimise the Windows image

## 🧩 Apps/AppV - /apps/appv

A set of scripts for installing applications to capture via application virtualization tools such as App-V.

## 📦 Nerdio Manager deployment - /nme

Terraform template for the deployment of Nerdio Manager for Enterprise into a target Azure subscription.

## 🐚 Shell Apps - /shell-apps

A set of example scripts for installing applications via [Shell Apps](https://nmehelp.getnerdio.com/hc/en-us/articles/25499430784909-UAM-Shell-apps-overview-and-usage). Also see: [Automating Nerdio Manager Shell Apps, with Evergreen, Part 1](https://stealthpuppy.com/nerdio-shell-apps-p1/).

## 🧪 Test - /tests

Windows image validation using Pester.

## 🛠️ Variables - /variables

Extending and simplifying Nerdio Manager secure variables with values hosted in a JSON file.

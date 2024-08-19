# Soundscape iOS App

This document describes how to build and run the Soundscape iOS app.

## Supported Tooling Versions

As of Soundscape Community version 1.0.1 (October 2023):

* macOS 12.6.1
* Xcode 13.4.1
* iOS 14.1

## Install Xcode

The Soundscape iOS app is developed on the Xcode IDE.

Download Xcode from the [App Store](https://apps.apple.com/us/app/xcode/id497799835?mt=12) or the [Apple Developer website](http://developer.apple.com).

## Install Xcode Command Line Tools

Open Xcode and you should be prompted with installing the command line tools, or run this in a Terminal window:

```sh
xcode-select --install
```

## Install Fastlane (optional)

Installing Fastlane requires a [Ruby](https://www.ruby-lang.org/) installation.

> __Note:__ while macOS comes with a version of Ruby installed, you should install and use a non-system [Ruby](https://www.ruby-lang.org/) using a version manager like [RVM](https://rvm.io/)

In the iOS project folder `apps/ios`, run the following command to install the dependencies from the `Gemfile`:

```sh
bundle install
```

## Opening the Project

At this point, you can open the `GuideDogs.xcworkspace` file, which is the main entry point to the Xcode project.
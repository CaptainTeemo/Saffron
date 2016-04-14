<p align="center">
  <img src="logo.png">
</p>
# Saffron
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.org/CaptainTeemo/Saffron.svg?branch=master)](https://travis-ci.org/CaptainTeemo/Saffron)
[![codecov.io](https://codecov.io/github/CaptainTeemo/Saffron/coverage.svg?branch=master)](https://codecov.io/github/CaptainTeemo/Saffron?branch=master)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/CaptainTeemo/Saffron/master/LICENSE.md)
[![GitHub release](https://img.shields.io/github/release/CaptainTeemo/Saffron.svg)](https://github.com/CaptainTeemo/Saffron/releases)

Saffron is a framework that gives a helping hand to download images and manage caches.

### Features
* Generic Cache struct that can cache everything.
* Convenient extensions for UIImageView do download and cache work for you.
* Built in loading animator which can be configured.
* GIF image support.
* Easy to use.

### At a glance
```swift
imageView.sf_setImage(#some image url string#)
```
That's all!

##### Cache
```swift
var stringCache = Cache<String>(cacheDirectoryPath: cachePath)
stringCache.write(key, value: value)

let cachedString = stringCache.fetch(key)
```


##### GIF image support
![](demo_gif.gif)


##### Circle reveal animation
```swift
func whereImageViewShouldBeInitialized() {
    let loader = DefaultAnimator(revealStyle: .Circle, reportProgress: false)
    imageView.sf_setAnimationLoader(loader)
}
```
![](demo_reveal.gif)


##### Fade reveal animation
```swift
func whereImageViewShouldBeInitialized() {
    let loader = DefaultAnimator(revealStyle: .Fade, reportProgress: false)
    imageView.sf_setAnimationLoader(loader)
}
```
![](demo_fade.gif)


##### Report download progress
```swift
func whereImageViewShouldBeInitialized() {
    let loader = DefaultAnimator(revealStyle: .Fade, reportProgress: true)
    imageView.sf_setAnimationLoader(loader)
}
```
![](demo_progress.gif)


### Requirements
* iOS 8.0+
* Xcode 7.3+

### Carthage
Put `github "CaptainTeemo/Saffron"` in your cartfile and run `carthage update` from terminal, then drag built framework to you project.

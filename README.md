<p align="center">
  <img src="https://raw.githubusercontent.com/CaptainTeemo/Saffron/master/logo.png">
</p>
# Saffron
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Build Status](https://travis-ci.org/CaptainTeemo/Saffron.svg?branch=master)](https://travis-ci.org/CaptainTeemo/Saffron)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/CaptainTeemo/Saffron/master/LICENSE.md)
[![GitHub release](https://img.shields.io/github/release/CaptainTeemo/Saffron.svg)](https://github.com/CaptainTeemo/Saffron/releases)
<!--[![codecov.io](https://codecov.io/github/CaptainTeemo/Saffron/coverage.svg?branch=master)](https://codecov.io/github/CaptainTeemo/Saffron?branch=master)-->

Saffron is a framework that gives a helping hand to download images and manage caches.

### Features
* Generic Cache struct that can cache everything.
* Convenient extensions for UIImageView that do download and cache things for you.
* Built in loading animator which can be configured.
* Options to process image (corner radius, scale and GaussianBlur).
* GIF image support.
* Easy to use.

### At a glance
```swift
imageView.sf_setImage(#some image url string#)
```
That's all!

**Process image**
```swift
imageView.sf_setImage(url, options: [.ScaleToFill(size), .CornerRadius(8), .GaussianBlur(10))
// image would be processed in order and assign the result image to imageView.
```

##### Cache
```swift
var stringCache = Cache<String>(cacheDirectoryPath: cachePath)
// write to cache
stringCache.write(key, value: value)

// fetch from cache
let cachedString = stringCache.fetch(key)
```


##### GIF image support
![](https://raw.githubusercontent.com/CaptainTeemo/Saffron/master/demo_gif.gif)


##### Circle reveal animation
```swift
func whereImageViewShouldBeInitialized() {
    let loader = DefaultAnimator(revealStyle: .Circle, reportProgress: false)
    imageView.sf_setAnimationLoader(loader)
}
```
![](https://raw.githubusercontent.com/CaptainTeemo/Saffron/master/demo_reveal.gif)


##### Fade reveal animation
```swift
func whereImageViewShouldBeInitialized() {
    let loader = DefaultAnimator(revealStyle: .Fade, reportProgress: false)
    imageView.sf_setAnimationLoader(loader)
}
```
![](https://raw.githubusercontent.com/CaptainTeemo/Saffron/master/demo_fade.gif)


##### Report download progress
```swift
func whereImageViewShouldBeInitialized() {
    let loader = DefaultAnimator(revealStyle: .Fade, reportProgress: true)
    imageView.sf_setAnimationLoader(loader)
}
```
![](https://raw.githubusercontent.com/CaptainTeemo/Saffron/master/demo_progress.gif)

### [API Documentation](http://rawgit.com/CaptainTeemo/Saffron/master/docs/index.html)


### Requirements
* iOS 8.0+
* Xcode 7.3+

### Carthage
Put `github "CaptainTeemo/Saffron"` in your cartfile and run `carthage update` from terminal, then drag built framework to you project.

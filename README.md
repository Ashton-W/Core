# CocoaPods Core

[![Master Build Status](https://secure.travis-ci.org/CocoaPods/Core.png?branch=master)](https://secure.travis-ci.org/CocoaPods/Core)

The CocoaPods-Core gem provides support to work with the models of CocoaPods. It is intended to be used in place of the CocoaPods when the the installation of the dependencies is not needed. Therefore, it is suitable for web services.

Provides support for working with the following models:

- `Pod::Specification` - [podspec files](http://cocoapods.github.com/specification.html).
- `Pod::Podfile` - [podfile specifications](http://cocoapods.github.com/podfile.html).
- `Pod::Source` - sources of podspec files like the [CocoaPods Spec repo](https://github.com/CocoaPods/Specs).

The gem also provides support for ancillary features like `Pod::Specification::Set::Presenter` suitable for presetting descriptions of Pods and the `Specification::Linter`, which ensures the validity of podspec files.

## Collaborate

All CocoaPods development happens on GitHub, there is a repository for [CocoaPods](https://github.com/CocoaPods/CocoaPods) and one for the [CocoaPods specs](https://github.com/CocoaPods/Specs). Contributing patches or Pods is really easy and gratifying. You even get push access when one of your specs or patches is accepted.

Follow [@CocoaPodsOrg](http://twitter.com/CocoaPodsOrg) to get up to date information about what's going on in the CocoaPods world.

## License

This gem and CocoaPods are available under the MIT license.
---
title: Using the Coordinator Pattern in iOS13+
date: 2020-08-06 08:31
categories:
  - Code
---

_(Note: This post uses Swift 5.2 and the iOS13 SDK)_

The **coordinator pattern** is probably my favorite "unofficial" design pattern in semi-common usage in the iOS community.

There's a lot of great articles out there about what it is and why it's beneficial[^1], so that's not my purpose here today. As of iOS13 and the introduction of the `SceneDelegate`, the way to implement it has changed a little bit, so I thought I'd write a bit about what needs to be done to make it work. <!--more-->

There's a lot of variations on the coordinator pattern; you can use one coordinator, you can use several conforming to a protocol, you can have the view controllers hold weak references to directly, you can have them interact only through custom delegate protocols, you can have one storyboard that contains all your view controllers, you can have one storyboard for each view controller, or anything between those extremes... so on and so forth. So for this example, I'll stick to the basic commonalities that are required to get started, and let you figure out the details of how you'd like to use the pattern with your app.

The best way to demonstrate this is to start off with a shiny new "Single View" iOS app. As an optional step, you might want to add a 'Hello world!' label to the view controller that comes with the default Xcode project just so you know that things are working as intended.

Next, you'll need to go to your project settings, and under the "General" tab, under "Deployment Info," you'll find a setting called "Main Interface". By default this is set to "Main," meaning that behind the scenes, your app will magically start up with the initial view controller of the `Main.storyboard` file. **We want to delete this**; we're going to handle setup of the window and the initial view controller ourselves in code.

The settings should look like the image below.

![Make sure `Main Interface` is blank in your project settings](/assets/images/coordinator_deleteMainInterface.png)

I seem to remember at some point having to remove some other things from the project settings and/or `Info.plist` file (other things that reference storyboards or `Main.storyboard`, basically), but this seems to be enough to get us going from my testing today.

Next, you'll want to create a new Swift file with the following content:

```swift
import UIKit

class AppCoordinator {
    private var window: UIWindow

    init(window: UIWindow) {
        self.window = window
    }

    func start() {
        window.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()
        window.makeKeyAndVisible()
    }
}
```

Again, usually there's also a `Coordinator` protocol that this conforms to (I actually like to make an abstract class that this subclasses), but for now we'll keep things simple.

Let's head over to the `SceneDelegate` and change it to contain the following:

```swift
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var appCoordinator: AppCoordinator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        window = UIWindow(windowScene: windowScene)
        appCoordinator = AppCoordinator(window: window!)
        appCoordinator?.start()
    }
    
    // ...other scene delegate methods
}
```

(Basically, we're just adding the `AppCoordinator` property and changing the body of the `scene(_:willConnectTo:options:)` method.)

Here's how I look at what's happening here:
- When the app launches, a new `UIWindowScene` (a subclass of `UIScene`) is made, and its `delegate` property is set to this class.
- That `scene` calls this delegate method.
- Usually, UIKit will handle initializing the window and setting its root view controller to be the initial view controller of the `Main` storyboard. Since we disabled that, we have to do it ourselves.
- We make sure our scene is a `UIWindowScene` (it might be a good idea to `fatalError` or `preconditionFailure` here if it's not).
- We initialize the `UIWindow` and make sure the `SceneDelegate` holds a reference to it.
- We use that window to initialize our `AppCoordinator`, which the `SceneDelegate` will also hold onto so it doesn't disappear into the ARC ether.
- We `start` our coordinator, which sets the root view controller of the window we made, making our view controller appear on the screen.

You should now be able to run your app. Congratulations! You're doing the coordinator pattern!

Obviously this isn't super-useful yet; the end result currently looks the same as it did before we changed anything. However, we've now unlocked a whole lot of power in terms of containment, testability, UI flow, and more. If you're still confused or not yet convinced, I'd encourage you to read the articles linked below to see how and why to use coordinators more effectively.

[^1]: Here's just a few articles about it:
    - [*The Coordinator* (the originator of the concept, as far as I'm aware!) (Soroush Khanlou)](https://khanlou.com/2015/01/the-coordinator/)
    - [*An iOS Coordinator Pattern* (Will Townsend)](https://will.townsend.io/2016/an-ios-coordinator-pattern)
    - [*How to use the coordinator pattern in iOS apps* (Paul Hudson)](https://www.hackingwithswift.com/articles/71/how-to-use-the-coordinator-pattern-in-ios-apps)
    - [*Advanced coordinators in iOS* (Paul Hudson)](https://www.hackingwithswift.com/articles/175/advanced-coordinator-pattern-tutorial-ios)

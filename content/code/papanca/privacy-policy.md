+++
title = "Papanca — Privacy Policy"
description = "Privacy policy for Papanca meditation timer"
weight = 1
+++

**Last updated: November 8, 2026**

## Summary

Papanca stores your meditation data locally on your device. There are no accounts and no advertising, and we never sell or share your information. The only information Papanca sends us is a random device ID and the app's version number, which go to our own feature flag server to decide which features to show. We may keep that ID, its app version, and which features it was served, to understand how new features roll out; it's deleted 30 days after your device last checks in.

## Data Storage

Stored on your device only:

- Session history (date, duration, and completion status of your meditation sessions)
- Timer presets and configurations
- App preferences and settings

This data never leaves your device unless you explicitly choose to back up your device through iCloud or iTunes.

## Feature Flags and Analytics

Papanca turns some features on or off, or tries different versions of a feature, using a feature flag server that we run ourselves. When the app opens or returns to the foreground, it asks that server which features to show, and sends:

- **A random device ID.** Papanca creates it the first time it runs and keeps it in your device's Keychain, so it stays the same if you delete and reinstall the app. It isn't your name, email, Apple Account, or Apple's advertising identifier, and it isn't included in backups, so a new or restored device gets a new ID.
- **The app's version number.**

The server may store, for each device ID:

- The device ID itself
- The app version it last reported
- Which version of each feature was served to it, and when it was first and last seen

We use this for analytics only: to see which devices get which version of a feature and to compare those versions (A/B testing). We don't use it for advertising, we don't combine it with data from other companies, and we don't share it with or sell it to anyone. The server is hosted by a cloud provider that stores it for us and doesn't use it for its own purposes.

**Retention:** this data is deleted automatically 30 days after the server last hears from your device.

**Deletion:** to have it deleted sooner, email us your device ID (see Contact below). To find it, open Settings in Papanca, touch and hold **Acknowledgements**, and choose **Copy Device ID**. We'll delete everything stored for that ID.

## HealthKit Integration

Papanca can optionally write Mindful Minutes to Apple Health. This feature:

- Requires your explicit permission
- Only writes data (session duration) — we don't read your health data
- Is handled entirely by Apple's HealthKit framework
- Can be disabled at any time in Settings

We have no access to your HealthKit data. It stays on your device and in your iCloud Health data (if you have that enabled with Apple).

## Third Parties

Papanca contains no:

- Analytics SDKs
- Advertising frameworks
- Social media integrations
- Third-party tracking

We don't share data with anyone. The feature flag server above is our own, not a third-party service.

## Children's Privacy

Papanca collects the same data from everyone, including children under 13: only the random device ID and the feature flag data described above. It never asks for names, email addresses, or other contact details.

## Changes

If this policy changes, we'll update the "Last updated" date above. Significant changes will be noted in app update release notes.

## Contact

Questions about this privacy policy:

- **Email:** junebash+papanca@pm.me
- **Developer:** June Bash

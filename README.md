# Hark

[Hark](https://github.com/joelhans/Hark) is being re-written from scratch. This time, it's all about Meteor.

## Installation

Clone the repo.

`git clone https://github.com/joelhans/hark-meteor.git`

cd into the directory.

`cd hark-meteor`

Install packages from [Atmosphere](https://atmosphere.meteor.com/).

`mrt add npm && mrt add moment && mrt add iron-router && mrt add font-awesome`

Run it!

`meteor`

Find it at `http://localhost:3000`.

Dockerfile incoming at some point...

## Todo

1. OPML import/export.
2. Ability to load more items in an individual feed.
3. Responsive/mobile layout.
4. Search.
5. Phonegap/Cordova support for mobile apps?

## Bugfixes

1. If an item is sync-ed, and a user re-starts it, it is marked as listened.
2. Some audio doesn't play on Linux. Problem with Flash?
3. Videos are not set to progress = 0 when played.

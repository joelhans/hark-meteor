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

1. Ability to load more items in an individual feed.
2. Responsive/mobile layout.
3. Search.
4. Phonegap/Cordova support for mobile apps?

## Bugfixes

1. Adding to the playlist while looking at the playlist leaves it blank. Deal with the left positioning.
2. Removing from the playlist has the same problem. Really, doing anything does.
3. If an item is sync-ed, and a user re-starts it, it is marked as listened.

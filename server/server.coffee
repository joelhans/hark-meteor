#############################
# TODO
#
# Add error handling for already added feed.
#
#############################

#############################
# REQUIRES
#############################

FeedParser = Meteor.require 'feedparser'
request    = Meteor.require 'request'
Fiber      = Meteor.require 'fibers'
Future     = Meteor.require 'fibers/future'

#############################
# COLLECTIONS
#############################

feeds = new Meteor.Collection 'feeds'
items = new Meteor.Collection 'items'
messages = new Meteor.Collection 'messages'

#############################
# FUNCTIONS
#############################

# ADD FEED
addFeed = (userId, url) ->
  return (meta) ->
    Fiber () ->
      # Ensure the user hasn't already added the feed. 
      if feeds.findOne {userId: userId, url: url}
        details = 'You already added this feed.'
        pushError userId, url, details
        return false
  
      # If the feed doesn't yet exist, go ahead and add it.
      feeds.insert {
        userId : userId
        title  : meta.title
        url    : url
      }, (err, feedId) ->
        if err
          details = 'Error adding this feed.'
          pushError userId, url, details
        if feedId
          refreshFeed feeds.findOne {_id: feedId}
    .run()

# REFRESH FEED

refreshFeed = (feed) ->
  count = 0

  request(feed.url)
    .pipe(new FeedParser())
    .on 'readable', () ->
      stream  = this
      item    = null
      ++count

      # A silly hack to mark only the most recent item as 'unlistened.'
      if count is 1
        while item = stream.read()
          addItem feed, item, false
      else if count >= 2
        while item = stream.read()
          addItem feed, item, true

# REFRESH FEEDS
refreshFeeds = () ->
  feeds.find({userId: Meteor.userId()}).forEach(refreshFeed)

# ADD ITEM
addItem = (feed, item, listened) ->
    Fiber () ->
      if items.findOne {feedId: feed._id, guid: item.guid}
        return false
      items.insert
        feedId   : feed._id
        userId   : feed.userId
        title    : item.title
        summary  : item.summary
        content  : item.description
        guid     : item.guid
        date     : item.date
        link     : item.link
        file     : item.enclosures
        listened : listened
    .run()

pushError = (userId, url, details) ->
  Fiber () ->
    messages.remove {userId: userId}
    messages.insert {
      userId  : userId
      message : details
    }
  .run()

#############################
# METHODS
#############################

Meteor.startup () ->
  Meteor.methods

    add: (url) ->
      userId = Meteor.userId()
      request(url)
        .on 'error', (err) ->
          # This is triggered on a prototcol error, from request.
          details = 'The URL you entered is not valid. ' +
                    'Please check it for accuracy.'
          pushError userId, url, details
        .pipe(new FeedParser())
        .on 'error', (err) ->
          # This is triggered by feedparser if it's not XML.
          details = 'There was an error adding feed '+url+'. ' +
                    'Check you entered the URL correctly' +
                    ', or try again later.'
          pushError userId, url, details
        .on 'meta', addFeed(userId, url)

    update: () ->
      refreshFeeds()

#############################
# PUBLISH
#############################
Meteor.publish 'messages', () ->
  return messages.find()

Meteor.publish 'feeds', () ->
  return feeds.find()

Meteor.publish 'items', () ->
  return items.find()

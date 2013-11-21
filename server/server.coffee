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

addFeed = (userId, url) ->
  return (meta) ->
    Fiber () ->
      # Ensure the user hasn't already added the feed. 
      if feeds.findOne {userId: userId, url: url}
        console.log 'You already added that feed.'
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
          console.log 'Feed added:',meta.title
    .run()

refreshFeed = (feed) ->
  request(feed.url)
    .pipe(new FeedParser())
    .on 'readable', () ->
      stream = this.read()
      item = null

      console.log stream

      for i in [0..20]
        console.log stream[i].title
      # while item = stream.read()
      #  addItem(feed, item)

refreshFeeds = () ->
  feeds.find {userId: this.userId}
    .fetch()
    .forEach refreshFeed(this)

addItem = (feed, item) ->
    Fiber () ->
      if items.findOne {feedId: feed._id, guid: items.guid}
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
        listened : false
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

#############################
# PUBLISH
#############################
Meteor.publish 'messages', () ->
  return messages.find()

Meteor.publish 'feeds', () ->
  return feeds.find()

Meteor.publish 'items', () ->
  return items.find()

#############################
# REQUIRES
#############################

FeedParser = Meteor.require 'feedparser'
request    = Meteor.require 'request'
Fiber      = Meteor.require 'fibers'
urlParser  = Meteor.require 'url'
resanitize = Meteor.require 'resanitize'

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
          feed = feeds.findOne {_id: feedId}
          refreshFeed feed, 'new'
    .run()

# REFRESH FEED
refreshFeed = (feed, source) ->
  Fiber () -> 
    count = 0

    request(feed.url)
      .on 'error', (err) ->
        # This is triggered on a prototcol error, from request.
        details = 'The URL you entered is not valid. ' +
                  'Please check it for accuracy.'
        pushError this.userId, feed.url, details
      .pipe(new FeedParser())
      .on 'error', (err) ->
        # This is triggered by feedparser if it's not XML.
        details = 'There was an error adding feed '+feed.url+'. ' +
                  'Check you entered the URL correctly' +
                  ', or try again later. ' + err
        pushError this.userId, feed.url, details
      .on 'readable', () ->
        stream  = this
        item    = null
        ++count

        if source is 'new'
          # A silly hack to mark only the most recent item as 'unlistened.'
          if count is 1
            while item = stream.read()
              addItem feed, item, false
          else if count >= 2
            while item = stream.read()
              addItem feed, item, true
        else if source is 'update'
          while item = stream.read()
            addItem feed, item, false
  .run()

# REFRESH FEEDS
refreshFeeds = () ->
  subs = feeds.find({userId: Meteor.userId()})
  subs.forEach (feed) ->
    refreshFeed feed, 'update'

# ADD ITEM
addItem = (feed, item, listened) ->
    Fiber () ->
      if items.findOne {feedId: feed._id, guid: item.guid}
        return false

      # Sanitize the summary and content fields.
      summary = resanitize(item.summary)
      content = resanitize(item.description)

      items.insert
        feedId   : feed._id
        feed     : feed.title
        userId   : feed.userId
        title    : item.title
        summary  : summary
        content  : content
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
      parsed = urlParser.parse url

      if parsed.protocol isnt 'http:' and parsed.protocol isnt 'https:'
        # This is triggered on a bad prototcol. 
        details = 'The URL must begin with "http://" or "https://". ' +
                  'Please check it for accuracy.'
        pushError userId, url, details
        return

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
                    ', or try again later. ' + err
          pushError userId, url, details
        .on 'meta', addFeed(userId, url)

    update: () ->
      refreshFeeds()

    destroy: (feed) ->
      feeds.remove({_id: feed._id})
      items.remove({userId: Meteor.userId(), feedId: feed._id})

    markListened: (id) ->
      items.update({userId: Meteor.userId(), _id: id}, {$set: {listened: true}})

    markUnListened: (id) ->
      items.update({userId: Meteor.userId(), _id: id}, {$set: {listened: false}})
    
    sync: (playing, progress) ->
      sync.upsert({userId: Meteor.userId()}, {$set: {userId: Meteor.userId(), playing: playing, progress: progress}})

    playlistAdd: (item) ->
      playlists.upsert({userId: Meteor.userId()}, {$set: {userId: Meteor.userId()}, $addToSet: {playlist: item}})

    playlistDestroy: (item) ->
      playlists.upsert({userId: Meteor.userId()}, {$set: {userId: Meteor.userId()}, $pull: {playlist: item}})
    
    playlistClear: (item) ->
      playlists.upsert({userId: Meteor.userId()}, {$set: {userId: Meteor.userId()}, $pull: {playlist: {userId: Meteor.userId}}})
    
    dismissError: () ->
      messages.remove {userId: Meteor.userId()}

#############################
# PUBLISH
#############################
Meteor.publish 'messages', () ->
  return messages.find()

Meteor.publish 'feeds', () ->
  return feeds.find()

Meteor.publish 'items', (params) ->
  return getItems(this.userId, params)

Meteor.publish 'sync', () ->
  return sync.find()

Meteor.publish 'playlists', () ->
  return playlists.find()

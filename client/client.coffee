#############################
# AUTORUN
#############################

Deps.autorun () ->
  Meteor.subscribe 'messages'
  Meteor.subscribe 'feeds'
  Meteor.subscribe 'items', {
    feedId: Session.get 'feedId'
    page: Session.get 'page'
  }
  Meteor.subscribe 'playlists'

#############################
# ROUTING
#############################

Router.map () ->

  this.route 'home', {
    path: '/'
    load: () ->
      Session.set 'feedId', undefined
      Session.set 'page', 0
  }

  this.route 'items', {
    path: '/feed/:_id'
    load: () ->
      Session.set 'feedId', this.params._id
  }
  
#############################
# HOME
#############################

Template.add.events =
  # Add new podcast.
  'click #add-podcast-form button': (e) ->
    e.preventDefault()
    input = document.getElementById('podcast-uri')
    if input.value isnt ''
      Meteor.call 'add', input.value
    input.value = ''
  
  # Update podcasts.
  'click #update': (e) ->
    e.preventDefault()
    Meteor.call 'update'

#############################
# TIMELINE
#############################

Template.timeline.items = () ->
  return getItems(Meteor.userId(), {
    feedId: Session.get 'feedId'
  }).map (item) ->
    return item

Template.timeline.rendered = () ->
  $('.moment').each (i) ->
    $(this).text(moment($(this).attr('date')).fromNow())

Template.timeline.events =
  # Play a podcast.
  'click .item-play': (e) ->
    e.preventDefault()
    playAudio this
  
  # Mark as listened.
  'click .item-listened': (e) ->
    e.preventDefault()
    Meteor.call 'markListened', this._id

  # Mark as un-listened.
  'click .item-unlistened': (e) ->
    e.preventDefault()
    Meteor.call 'markUnListened', this._id
  
  # Add to playlist.
  'click .item-add-playlist': (e) ->
    e.preventDefault()
    Meteor.call 'playlistAdd', this

#############################
# FEEDS
#############################

Template.subscriptions.feeds = () ->
  return feeds.find({userId: Meteor.userId()}, {sort: [['title','asc']]})

Template.subscriptions.events =
  # Destroy.
  'click .feed-destroy': (e) ->
    e.preventDefault()
    if window.confirm "Really remove " + this.title + "?"
      Meteor.call 'destroy', this

#############################
# PLAYLIST
#############################
Template.playlist.list = () ->
  return playlists.find({userId: Meteor.userId()}).fetch()

Template.playlist.events =
  # Play playlist item, cut it from the playlist.
  'click .playlist-item': (e) ->
    playAudio this
    Meteor.call 'playlistDestroy', this

  # Destroy.
  'click .playlist-destroy': (e) ->
    e.preventDefault()
    Meteor.call 'playlistDestroy', this

  'click .playlist-clear': (e) ->
    e.preventDefault()
    Meteor.call 'playlistClear', this

#############################
# PLAYER
#############################

Meteor.subscribe 'sync', () ->
  Session.set 'playing', sync.find({userId: Meteor.userId()}).fetch()[0].playing
  Session.set 'progress', sync.find({userId: Meteor.userId()}).fetch()[0].progress
  playerAudio.pause()
  file = Session.get('playing').file[0].url
  playerAudio.setSrc file, type: 'audio/mp3'

# Play audio!
playAudio = (data) ->
  Session.set 'playing', data
  Session.set 'progress', 1
  Meteor.call 'sync', data, Session.get 'progress'
  playerAudio.pause()
  playerAudio.setSrc data.file[0].url, type: 'audio/mp3'
  playerAudio.play()

playerAudio = updateProgress = null
Template.player.rendered = () ->
  playerAudio = new MediaElementPlayer '.player-audio', {
    audioWidth: 800
    audioHeight: 30
    startVolume: 0.5
    plugins: ['flash','silverlight']
    pluginPath: 'js/'
    flashName: 'flashmediaelement.swf'
    silverlightName: 'silverlightmediaelement.xap'

    success: (mediaElement, domObject) ->
      # On player load, set the progress from sync.
      mediaElement.addEventListener 'loadedmetadata', (e) ->
        progress = Session.get 'progress'
        file = Session.get('playing').file[0].url
        mediaElement.setCurrentTime progress
     
      # On playing, update progress every 10 seconds, sync to server.
      mediaElement.addEventListener 'playing', (e) ->
        updateProgress = setInterval () ->
          Session.set 'progress', e.target.currentTime
          Meteor.call 'sync', Session.get('playing'), Session.get('progress')
        , 10000

      # On pause, halt the updateProgress interval.
      mediaElement.addEventListener 'pause', (e) ->
        clearInterval updateProgress
     
      # Mark an item as "listened" upon finishing it.
      # If there is a playlist, destroy the current item,
      # and move on to the next one.
      mediaElement.addEventListener 'ended', (e) ->
        clearInterval updateProgress
        Meteor.call 'markListened', Session.get('playing')._id
        Meteor.call 'playlistDestroy', Session.get 'playing'
        if $('.playlist ul li').length
          playAudio playlists.find({userId: Meteor.userId()}).fetch()[0].playlist[0]
  }


Template.playing.current = () ->
  return sync.find({userId: Meteor.userId()}).fetch()

Template.player.current = () ->
  return sync.find({userId: Meteor.userId()}).fetch()

#############################
# NOTIFY/ERRORS
#############################

Template.notify.helpers
  messages: () -> 
    if messages.find({userId: Meteor.userId()}).fetch()[0]? is true
      Session.set 'errorShow', true
    else
      Session.set 'errorShow', false
    return messages.find({userId: Meteor.userId()}).fetch()

Template.notify.showHide = () ->
  return Session.equals('errorShow', true) ? 'hidden' : ''

Template.notify.events =
  'click': (e) ->
    Session.set 'errorShow', false
    Meteor.call 'dismissError'

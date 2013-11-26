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
      Session.set 'page', 0
  }
  
#############################
# HOME
#############################

Template.add.events =
  # Add new podcast.
  'click #add-podcast-form .add': (e) ->
    e.preventDefault()
    $('#add-podcast-form .add, #update').hide()
    $('#add-podcast-form .confirm, #add-podcast-form input').show()
  
  'click #add-podcast-form .confirm': (e) ->
    e.preventDefault()
    input = document.getElementById('podcast-uri')
    if input.value isnt ''
      Meteor.call 'add', input.value
    input.value = ''
    $('#add-podcast-form .add, #update').show()
    $('#add-podcast-form .confirm, #add-podcast-form input').hide()
  
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
    page: Session.get 'page'
  }).map (item) ->
    return item

Template.timeline.rendered = () ->
  $('.moment').each (i) ->
    $(this).text(moment($(this).attr('date')).fromNow())

Template.timeline.events =
  # Play a podcast.
  'click .item-play': (e) ->
    e.preventDefault()
    audioOrVideo this, true, false
  
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

  # Load more.
  'click .load-more': (e) ->
    console.log Session.get 'page'
    Session.set('page', (Session.get('page') || 0) + 1)
    console.log Session.get 'page'

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

# Size the left sidebar according to the window height.
Template.subscriptions.rendered = () ->
  $('.left').height $(window).height() - 50

# Re-trigger that on window re-size.
$(window).resize () ->
  $('.left').height $(window).height() - 50

#############################
# PLAYLIST
#############################
Template.playlist.list = () ->
  return playlists.find({userId: Meteor.userId()}).fetch()

Template.playlist.events =
  # Play playlist item, cut it from the playlist.
  'click .playlist-item': (e) ->
    audioOrVideo this, true, false
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

# Play audio!
playAudio = (data, auto, sync) ->
  Session.set 'playing', data
  if sync is false
    Session.set 'progress', 0
  Meteor.call 'sync', data, Session.get 'progress'
  playerAudio.pause()
  playerAudio.setSrc data.file[0].url, type: 'audio/mp3'
  if auto is true
    playerAudio.play()
  else
    playerAudio.pause()

# Play audio!
playVideo = (data, auto, sync) ->
  Session.set 'playing', data
  if sync is false
    Session.set 'progress', 0
  Meteor.call 'sync', data, Session.get 'progress'
  playerVideo.pause()
  playerVideo.setSrc data.file[0].url
  if auto is true
    playerVideo.play()
  else
    playerVideo.pause()

# Help choose between video or audio
audioOrVideo = (data, auto, sync) ->
  file = data.file[0].url
  if file.indexOf('mp4') isnt -1
    $('.player-audio').hide()
    $('.player-video').show()
    playVideo data, auto
  else
    $('.player-video').hide()
    $('.player-audio').show()
    playAudio data, auto, sync

playerAudio = playerVideo = updateProgress = null

playerOptions = 
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
        , 1000

      # On pause, halt the updateProgress interval.
      mediaElement.addEventListener 'pause', (e) ->
        clearInterval updateProgress
     
      # Mark an item as "listened" upon finishing it.
      # If there is a playlist, destroy the current item,
      # and move on to the next one.
      mediaElement.addEventListener 'ended', (e) ->
        clearInterval updateProgress
        Meteor.call 'markListened', Session.get('playing')._id
        if $('.playlist ul li').length
          audioOrVideo playlists.find({userId: Meteor.userId()}).fetch()[0].playlist[0], true, false
        Meteor.call 'playlistDestroy', Session.get('playing')

# Establishing the players on template render.
Template.player.rendered = () ->
  playerAudio = new MediaElementPlayer '.player-audio', playerOptions
  playerVideo = new MediaElementPlayer '.player-video', playerOptions

  # Wait until the DOM is finished loading, then pause the players. Then,
  # grab the 'playing' data from the session, which should have been set
  # by subscribing to the sync database.
  Meteor.defer () ->
    playerAudio.pause()
    playerVideo.pause()
    audioOrVideo Session.get('playing'), false, true

# Update the currently playing template on sync changes.
Template.playing.current = () ->
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

Template.notify.rendered = () ->
  $notify = $(this.find('.notify'))
  Meteor.defer () ->
    if Session.equals 'errorShow', true
      console.log $notify.outerWidth()
      $notify.addClass 'error-show'

Template.notify.events =
  'click': (e) ->
    Session.set 'errorShow', false
    Meteor.call 'dismissError'

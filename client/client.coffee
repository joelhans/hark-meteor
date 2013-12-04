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

# Set interval to update every 30 minutes.
Meteor.setInterval () ->
  Meteor.call 'update'
, 18000000

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
  # First step in adding new podcast. Hide the "Add" button,
  # show the "+"/confirm button, and the input area.
  'click #add-podcast-form .add': (e) ->
    e.preventDefault()
    $('#add-podcast-form .add, #update').hide()
    $('#add-podcast-form .confirm, #add-podcast-form input').show()
 
  # Second step in adding new podcast. Ensure that there is a
  # an input. If so, call the add method, reset the buttons.
  'click #add-podcast-form .confirm': (e) ->
    e.preventDefault()
    input = document.getElementById('podcast-uri')
    if input.value isnt ''
      Meteor.call 'add', input.value
    #
    # TODO: Add in error handling for this.
    #
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

Template.timeline.rendered = () ->
  # Moment-ize all the dates in the timeline.
  $('.moment').each (i) -> $(this).text(moment($(this).attr('date')).fromNow())

  # Click on the logo, scroll to top.
  $('.header-logo').click () -> $('body').stop().animate { scrollTop: '0' }

# Header-related bits.
$(document).scroll () ->
  if $(document).scrollTop() > 53
    $('header').addClass 'header-mini'
    $('#items').css 'margin-top', 110
    $('header').width $('#container').width() - 240
  else
    $('header').removeClass 'header-mini'
    $('#items').css 'margin-top', ''

#############################
# FEEDS
#############################

Template.subscriptions.feeds = () ->
  return feeds.find({userId: Meteor.userId()}, {sort: [['title','asc']]})

Template.subscriptions.events =
  # Switch to playlist view.
  'click .feed-playlist': (e) ->
    e.preventDefault()
    $('.feeds-playlist-switcher').addClass 'playlistShow'
    $('.playlist').animate {left: '0'}, 200
    $('.feeds').animate {left: '-220'}, 200

  # Switch to "all feeds" view. 
  'click .feed-all': (e) ->
    $('.feeds-playlist-switcher').removeClass 'playlistShow'
    $('.feeds').animate {left: '0'}, 200
    $('.playlist').removeClass('visible').animate {left: '220'}, 200

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

  # Clear playlist.
  'click .playlist-clear': (e) ->
    e.preventDefault()
    Meteor.call 'playlistClear', this

Template.playlist.rendered = () ->
  # On render, we check to make sure if the playlist is supposed
  # to be visible. If so, we keep it in its proper place.
  Meteor.defer () ->
    if $('.feeds-playlist-switcher').is '.playlistShow'
      $('.playlist').css 'left', 0

#############################
# PLAYER
#############################

playerAudio = playerVideo = updateProgress = null

# Set up sync.
# We look for sync data. If there is some, we set the Session
# accordingly. If not (new user), we give these empty/0 values 
# so that we can move on.
Meteor.subscribe 'sync', () ->
  syncData = sync.find({userId: Meteor.userId()}).fetch()[0]
  if syncData?
    Session.set 'playing', sync.find({userId: Meteor.userId()}).fetch()[0].playing
    Session.set 'progress', sync.find({userId: Meteor.userId()}).fetch()[0].progress
  else 
    Session.set 'playing', []
    Session.set 'progress', 0

# Play audio
# Usage: playAudio data, true/false, true/false
# This resets progress, sets the file in the <audio> element,
# and either begins playing or waits for the user.
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

# Play video
# Usage: playVideo data, true/false, true/false
# This resets progress, sets the file in the <video> element,
# and either begins playing or waits for the user.
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

# Help choose between video or audio.
# Essentially, check if there are 'mp3' or 'mp4' in the url string,
# and redirect accordingly.
audioOrVideo = (data, auto, sync) ->
  file = data.file[0].url
  if file.indexOf('mp4') isnt -1
    $('.player-audio').hide()
    $('.player-video, .player-video-extras').show()
    playVideo data, auto
  else
    $('.player-video, .player-video-extras').hide()
    $('.player-audio').show()
    playAudio data, auto, sync

# Default player options.
# These are applicable to both players, and are used accordingly.
playerOptions = 
    videoWidth: 800
    videoHeight: 450
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

    # Extras related to the video player.
    videoLeft = ($(window).width() - $('.mejs-video').width()) / 2 + $('.mejs-video').width() - 1
    $('.player-video-extras').css 'left', videoLeft

Template.player.events =

  'click .fa-minus-square': (e) ->
    e.preventDefault()
    $('.mejs-mediaelement, .mejs-layers, .player-video-extras').toggleClass 'video-hidden'

# Update the currently playing template on sync changes.
Template.playing.current = () ->
  return sync.find({userId: Meteor.userId()}).fetch()

#############################
# NOTIFY/ERRORS
#############################

Template.notify.helpers
  # If there are messages, set the session variables
  messages: () -> 
    if messages.find({userId: Meteor.userId()}).fetch()[0]? is true
      Session.set 'errorShow', true
    else
      Session.set 'errorShow', false
    return messages.find({userId: Meteor.userId()}).fetch()

Template.notify.rendered = () ->
  # On render, we look to see if the session variable is true.
  # If so, add a class to the notification window to show it.
  $notify = $(this.find('.notify'))
  Meteor.defer () ->
    if Session.equals 'errorShow', true
      $notify.addClass 'error-show'

Template.notify.events =
  # Dismiss the error notification window.
  'click': (e) ->
    Session.set 'errorShow', false
    Meteor.call 'dismissError'

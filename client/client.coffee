feeds = new Meteor.Collection 'feeds'
items = new Meteor.Collection 'items'
messages  = new Meteor.Collection 'messages'

Deps.autorun () ->
  Meteor.subscribe 'messages'
  Meteor.subscribe 'feeds'
  Meteor.subscribe 'items'

#############################
# PLAYER
#############################

playerAudio = null
Template.player.rendered = () ->
  playerAudio = new MediaElementPlayer '.player-audio', {
    audioWidth: 800
    audioHeight: 30
    enablePluginDebug: true 
    plugins: ['flash','silverlight']
    pluginPath: 'js/'
    flashName: 'flashmediaelement.swf'
    silverlightName: 'silverlightmediaelement.xap'
  }

#############################
# HOME
#############################

# Get current user.
Template.home.user = ->
  Meteor.user()

Template.home.events =
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

Template.timeline.events =
  # Mark as listened.
  'click .item-listened': (e) ->
    e.preventDefault()
    console.log 'hi'
    console.log this._id

  'click .item-play': (e) ->
    e.preventDefault()
    playerAudio.pause()
    playerAudio.setSrc this.file[0].url, type: 'audio/mp3'
    playerAudio.play()

#############################
# SUBSCRIPTIONS
#############################

Template.subscriptions.feeds = () ->
  return feeds.find({userId: Meteor.userId()}).fetch()

Template.timeline.items = () ->
  return items.find({userId: Meteor.userId(), listened: false}, [sort: ['date', 'desc']]).fetch()

Template.notify.helpers
  messages: () -> 
    $('#notify').show() 
    return messages.find({userId: Meteor.userId()}).fetch()

Template.notify.events =
  'click #notify': (e) ->
    messages.remove {userId: Meteor.userId()}

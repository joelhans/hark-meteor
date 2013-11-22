feeds = new Meteor.Collection 'feeds'
items = new Meteor.Collection 'items'
messages  = new Meteor.Collection 'messages'

Deps.autorun () ->
  Meteor.subscribe 'messages'
  Meteor.subscribe 'feeds'
  Meteor.subscribe 'items'

newPodcast = () ->
  input = document.getElementById('podcast-uri')
  if input.value isnt ''
    Meteor.call 'add', input.value
  input.value = ''

# Get current user.
Template.home.user = ->
  Meteor.user()

# Add a new podcast.
Template.home.events =
  'click #add-podcast-form button': (e) ->
    e.preventDefault()
    newPodcast()

  'click #update': (e) ->
    e.preventDefault()
    Meteor.call 'update'

Template.subscriptions.feeds = () ->
  return feeds.find({userId: Meteor.userId()}).fetch()

Template.timeline.items = () ->
  return items.find({userId: Meteor.userId(), listened: false}).fetch()



Template.notify.helpers
  messages: () -> 
    $('#notify').show() 
    return messages.find({userId: Meteor.userId()}).fetch()

Template.notify.events =
  'click #notify': (e) ->
    messages.remove {userId: Meteor.userId()}

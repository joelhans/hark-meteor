feeds = new Meteor.Collection 'feeds'
items = new Meteor.Collection 'items'
messages  = new Meteor.Collection 'messages'

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

Template.subscriptions.feeds = () ->
  return feeds.find({userId: Meteor.userId()}).fetch()

Template.timeline.items = () ->
  return items.find()

Deps.autorun () ->
  Meteor.subscribe 'messages'
  Meteor.subscribe 'feeds'

Template.notify.helpers
  messages: () -> 
    return messages.find({userId: Meteor.userId()}).fetch()

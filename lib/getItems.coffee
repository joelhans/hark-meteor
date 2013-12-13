#############################
# COLLECTIONS
#############################

@items     = new Meteor.Collection 'items'
@feeds     = new Meteor.Collection 'feeds'
@sync      = new Meteor.Collection 'sync'
@messages  = new Meteor.Collection 'messages'
@playlists = new Meteor.Collection 'playlists'

#############################
# GET ITEMS
#############################

@getItems = (userId, params) ->
  ITEMS_PER_LOAD = 10
  selectors = userId: userId
  options = sort: [['date', 'desc']]

  # If we're looking at the main feed.
  if !params.feedId 
    selectors.listened = false

  # If we're looking at an individual feed.
  else
    selectors.feedId = params.feedId
    options.limit = ITEMS_PER_LOAD
    options.skip = (params.page || 0) * ITEMS_PER_LOAD

  console.log options

  return items.find(selectors, options)

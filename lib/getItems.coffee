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
  # ITEMS_PER_LOAD = 1
  selectors = userId: userId
  options = sort: [['date', 'desc']]
  # options.limit = ITEMS_PER_LOAD
  # options.skip = (params.page || 0) * ITEMS_PER_LOAD

  if params.feedId 
    selectors.feedId = params.feedId
  else
    selectors.listened = false

  # console.log options

  return items.find(selectors, options)

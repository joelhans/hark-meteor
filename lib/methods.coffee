throwError = (error, reason, details) ->
  error = new Meteor.Error error, reason, details
  if Meteor.isClient then error else throw error

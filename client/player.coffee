if Meteor.isClient
  playerAudio = null

  

  Template.player.rendered = () ->

    console.log 'hi'

    playerAudio = new MediaElementPlayer '.player-audio', {
      enablePluginDebug: true 
      plugins: ['flash','silverlight']
      pluginPath: '/js/'
      flashName: 'flashmediaelement.swf'
      silverlightName: 'silverlightmediaelement.xap'
      success: () ->
        console.log 'ready'
    }

  Template.timeline.events =

    'click #items li a': (e) ->
      e.preventDefault()
      console.log 'play this: ' + this.file[0].url

      playerAudio.pause()
      playerAudio.setSrc this.file[0].url, type: 'audio/mp3'

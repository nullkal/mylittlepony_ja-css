fs   = require 'fs'
path = require 'path'
cson = require 'cson'

Snoocore = require 'snoocore'
mime = require 'mime'

fetchRemoteFlairTemplates = (reddit, target) ->
  reddit("/r/#{target}/api/flairselector").post().then((res)->
    flairs = {}
    for raw_flair in res['choices'] 
      flairs[raw_flair['flair_text']] = {
        css_class: raw_flair['flair_css_class'].replace(/^flair-/, ''),
        template_id: raw_flair['flair_template_id']
      }
    return flairs
  )

module.exports = (build_dir) ->
  config = cson.load('config.cson')
  flairTemplates = cson.load('flair-templates.cson')
  reddit = new Snoocore(
    userAgent: 'mylittlepony_ja-css:v1.0.0 (by /u/nullkal)',
    oauth: {
      type: 'script',
      key: config['app_key'],
      secret: config['app_secret'],
      username: config['username'],
      password: config['password'],
      scope: ['flair', 'modconfig', 'modflair']
    }
  )
  (new Promise (onFulfilled, onRejected) ->
      fs.readdir 'build', (err, data) ->
          return onRejected(err) if err
          onFulfilled(data)
  )
    .then (files) ->
      tasks = []
      for f in files
        ext = path.extname f
        if ext == '.png' || ext == '.jpg'
          tasks.push ((f, ext) -> new Promise (onFulfilled, onRejected) ->
            fs.readFile "build/#{f}", (err, data) ->
              return onRejected(err) if err
              onFulfilled(
                reddit("/r/#{config['subreddit']}/api/upload_sr_img")
                  .post
                    file: Snoocore.file(f, mime.lookup(f), data),
                    img_type: ext.slice(1),
                    name: path.basename(f, ext),
                    upload_type: 'img'
                  .then ->
                    console.log "UPLOAD IMAGE: #{f}"
              )
          )(f, ext)
      Promise.all(tasks)
    .then ->
      new Promise (onFulfilled, onRejected) ->
        fs.readFile 'build/style.css', 'utf-8', (err, data) ->
          return onRejected(err) if err
          onFulfilled(data)
    .then (styleSheet) ->
      reddit("/r/#{config['subreddit']}/api/subreddit_stylesheet")
        .post
          op: 'save',
          reason: '',
          stylesheet_contents: styleSheet
        .then ->
          console.log 'UPDATE CSS'
    .then ->
      fetchRemoteFlairTemplates(reddit, config['subreddit'])
    .then (remoteFlairTemplates) ->
      tasks = []
      for ftText, ftClass of flairTemplates
        if !(ftText of remoteFlairTemplates) ||
            ftClass != remoteFlairTemplates[ftText].css_class
          tasks.push(
            ((ftText, ftClass) ->
              reddit("/r/#{config['subreddit']}/api/flairtemplate")
                .post
                  text: ftText,
                  css_class: ftClass,
                  flair_type: 'USER_FLAIR',
                  text_editable: false
                .then ->
                  console.log "NEW FLAIR: #{ftText}:#{ftClass}"
            )(ftText, ftClass)
          )
      for ftText, ftInfo of remoteFlairTemplates
        if !(ftText of remoteFlairTemplates) ||
            ftInfo.css_class != flairTemplates[ftText]
          tasks.push(
            ((ftText, ftInfo) ->
              reddit("/r/#{config['subreddit']}/api/deleteflairtemplate")
                .post
                  flair_template_id: ftInfo.template_id
                .then ->
                  console.log "DEL FLAIR: #{ftText}:#{ftInfo.css_class}"
            )(ftText, ftInfo)
          )
      Promise.all(tasks)

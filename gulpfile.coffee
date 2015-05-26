fs   = require 'fs'
path = require 'path'

module.paths.push path.join(__dirname, 'lib')
update_css = require 'update_css'

g = require 'gulp'
clean   = require 'gulp-clean'
plumber = require 'gulp-plumber'
merge   = require 'merge-stream'
replace = require 'gulp-replace'

sass     = require 'gulp-ruby-sass'
pleeease = require 'gulp-pleeease'
header   = require 'gulp-header'

imagemin    = require 'gulp-imagemin'
spritesmith = require 'gulp.spritesmith'

g.task 'default', ['compile:sprites'], ->
  sass 'style.sass', require: 'sass-globbing'
    .pipe plumber()
    .pipe replace(/^@charset\s*['"].+?['"]\s*;\s*\n?/i, '')
    .pipe pleeease(
      autoprefixer: {browsers: ['last 2 versions']}
      minifier: true)
    .pipe header(fs.readFileSync('header.css', 'utf8'))
    .pipe g.dest('build')

getDirectories = (dir)->
  fs.readdirSync(dir).filter (file)->
    fs.statSync(path.join(dir, file)).isDirectory()

g.task 'compile:sprites', ->
  makeSprite = (dir, parents = [])->
    dirStack = parents.concat([dir])
    setName = dirStack.slice(1).join('-')
    setPath = dirStack.join('/')
    sprite = g.src "#{setPath}/*.png"
      .pipe spritesmith(
        imgName: "#{setName}.png"
        cssName: "#{setPath}.sass",
        imgPath: "%%#{setName}%%",
        cssTemplate: 'sprites.sass.handlebars',
        cssSpritesheetName: setName)
    tasks = []
    tasks.push(
      sprite.img
        .pipe imagemin()
        .pipe g.dest('build')
    )
    tasks.push(
      sprite.css
        .pipe g.dest('gen')
    )
    tasks.concat getDirectories(setPath).map (d)->
      makeSprite(d, dirStack)
  merge(makeSprite('sprites'))

g.task 'clean', ->
  g.src ['build', 'gen'], read: false
    .pipe clean()

g.task 'update-css', ->
  update_css('build')

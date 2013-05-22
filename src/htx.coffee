#!/usr/bin/env coffee

###
  htx - Website/WebApp Inliner/Compressor
  c) 2013 anx<xmpp>ulzq - GNU GPLv3 - No warranty!
###

coffee    = require 'coffee-script'
cheerio   = require 'cheerio'
uglifyjs  = require("uglify-js").minify
uglifycss = require("uglifycss").processString
# tidy      = require('tidy2').tidyString
http      = require 'http'
https     = require 'https'
fs        = require 'fs'
util      = require 'util'
colors    = require 'colors'
crypto    = require 'crypto'
url       = require 'url'
md5       = (data) -> crypto.createHash('md5').update(data).digest("hex")
sha512    = (data) -> crypto.createHash('sha512').update(data).digest("hex")

String::basename = -> return this.split('/').pop()
UA_CHROME = "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.43 Safari/537.31"

class htx
  @count  = 0
  @byPath = {}
  
  @getid  : (path) -> return if @byPath[path]? then @byPath[path] else @byPath[path] = @count++
  @pathExists : (path) -> return @byPath[path]?

  @defaults : ->
    debug : no
    verbose : no
    compress : on
    warn_missing : off
    recompile : off
    hashes : off

  @create  : (opts={}) ->
    { @template, @dest, @compress, @webroot, @hashes, @warn_missing, @recompile, @verbose } = opts
    @top = yes
    @js_opts = { fromString : on, inline_script : yes, beautify: yes }
    @verbose = yes if @debug is yes
    @hashes = off if @verbose is yes
    if @verbose or @hashes
      util.print "[" + "compile".blue + "] " + @template.yellow + " -> " +
        @dest.yellow + " " + (if @verbose then "\n" else "")
    t = new htx this, "html", @template
    @child_ready = (result) =>
      fs.writeFileSync @dest, result
      console.log (if @hashes then " " else "") + "[" + "done".green + ":" + t.path.blue + "]" if @verbose or @hashes

  @help : ->
    console.log """ usage: htx OPTIONS\n
      MANDATORY:
        -t --template      (the entry point to your webapp)
        -d --dest          (the resulting compiled file)
        -w --webroot       (the asset/webroot)\n
      OPTIONAL:
        -h --help
        -H --hashes        (show dots'n'hashes)
        -v --verbose       (turns off hashes)
        -c --dont-compress (uglify)
        -R --recompile     (update when a file is changed)
        -W --warn-missing\n
      DEPS:
        npm install -g cheerio uglify-js2 uglifycss tidy2\n
      htx - Website/WebApp Inliner/Compressor
        c) 2013 anx@ulzq.de - GNU GPLv3 - No warranty!\n
    """; process.exit(0)

  @cli : (args) ->
    opts = @defaults()
    while args.length > 0
      arg = args.shift()
      switch arg
        when "-h", "--help"          then @help()
        when "-D", "--debug"         then opts.debug        = yes
        when "-v", "--verbose"       then opts.verbose      = yes
        when "-H", "--hashes"        then opts.hashes       = on
        when "-c", "--dont-compress" then opts.compress     = off
        when "-R", "--recompile"     then opts.recompile    = on
        when "-W", "--warn-missing"  then opts.warn_missing = on
        when "-t", "--template"      then opts.template     = args.shift()
        when "-d", "--dest"          then opts.dest         = args.shift()
        when "-w", "--webroot"       then opts.webroot      = args.shift()
    errors = no
    for i in ["template","dest","webroot"]
      unless opts[i]?
        errors = yes 
        console.error "#{i} is not defined (-#{i[0]})"
    process.exit 1 unless errors is no
    @create opts

  constructor : (@parent,@type,@path,@finalize) ->
    { @template, @dest, @compress, @webroot, @hashes, @warn_missing, @recompile,
      @verbose, @js_opts, @debug } = @parent

    unless @js_opts?
      console.log @path
      process.exit(1)

    @is_ready = false ; @child = {} ; @buffer = ""

    @http_request = @path.indexOf("http") is 0
    @inline       = @path.indexOf("inline") is 0
    @id           = htx.getid @path

    if @inline
      @inline_data = @path.substring 7
      @path = "inline:#{@id}"
    else
      @path   = "#{@webroot}/#{@path.replace(/^\//,'')}" unless @http_request
      @mime   = "image/"+@path.split('\.').pop()                   # maybe FIXME -> do real mime-mapping
      @mime   = "image/svg+xml" if @mime is "image/svg"            # this is not really elegant
      @mime   = "font/ttf" if @mime is "image/ttf"                 # this is not really elegant
      @mime   = "application/x-font-woff" if @mime is "image/woff" # this is not really elegant
      @suffix = @path.split(".").pop()
    
    @placeholder = if typeof this[@type] is "function" then this[@type]() else undefined
    unless @placeholder?
      console.error "missing @placeholder #{@type} #{path}"
      process.exit(1)
    unless typeof @process is "function"
      console.error "missing @proceess #{@type} #{path}"
      process.exit(1)

    if @inline
      # console.log "inline: #{type} #{@inline_data.trim()}"
      @process @inline_data
    else if @http_request
      # Try to load cache, it that fails, well: fetch()
      fs.exists ( @hash = "/tmp/_#{md5(@path).trim()}" ), (cache_exists) =>
        if cache_exists
          fs.readFile @hash, (err,buf) =>
            return @http_fetch() if err?
            @buffer = buf.toString("utf-8")
            console.log "[" + "cached".green + "] " + @path if @verbose
            @child_ready()
        else @http_fetch()
    else if fs.existsSync @path
      # console.log "fetch?[" + @path.red + "]"
      @file_fetch()
      if @recompile then @watch = fs.watch @path, (e,f) =>
          util.print "[" + e.blue + "] " + f + " "
          @file_fetch()
    else
      unless @parent.top?
        #console.warn "[#{"MISSING".red}] #{@path.blue}" if @warn_missing
        @invalid = true

  new_child : (type,url) =>
    @is_ready = false
    # console.log "#{@path.basename()} -> #{url.basename()}"
    c = new htx @, type, url
    @child[c.id] = c
    return c.placeholder

  html : =>
    util.print "H".yellow if @hashes
    @format = "utf-8"
    @process = (code) =>
      $ = cheerio.load code
      console.log "[" + "html".blue + "] " + @path.basename().yellow if @verbose
      for tag in $("head link") when (src = tag.attribs.href)? # and !tag.attribs.extern?
        $(tag).replaceWith """<style type="text/css">#{@new_child "css", src}</style>"""
      for tag in $("script") when !tag.attribs.extern?
        src = (if tag.attribs.src? then tag.attribs.src else "inline:"+$(tag).html().trim())
        $(tag).attr("src",null)
        if tag.attribs.coffee? then $(tag).text(@new_child "coffee",src)
        else $(tag).text(@new_child "js",src)
      for tag in $("img") when tag.attribs.src? and !tag.attribs.extern?
        $(tag).attr("src", @new_child "image", tag.attribs.src)
      @buffer = $.html()
      @buffer = @buffer.replace "text/coffeescript","text/javascript"
      # @buffer = tidy(@buffer)
      @child_ready()
    return "XXX#{@id}XXX"

  image : (css)=>
    util.print "A".blue if @hashes
    @id = 2000 + @id
    @format = 'base64'
    @process = (code) =>
      # code = code.replace("\n","").trim() if @compress
      console.log "[#{@type.blue}] #{@path.basename()} #{code.substring 0,60}" if css? and @mime is "font/ttf"
      code =  "data:#{@mime};base64,#{code}"
      @buffer = if css? then "url(" + code + ");" else code
      @child_ready()
    return "XXX#{@id}XXX"

  css_ref : => return @image true

  css : =>
    util.print "C".green if @hashes
    @format = "utf-8"
    @process = (code) =>
      @buffer = uglifycss(code,beautify:yes).toString() if @compress
      urls = /url\(['"]?([^\"')]+)['"]?\);?/gi
      @buffer = @buffer.replace urls, (all,path) => return @new_child "css_ref",path
      console.log "[" + "css".blue + "] " + @path.basename().yellow if @verbose
      @child_ready()
    return "XXX#{@id}XXX"

  js : =>
    util.print "J".yellow if @hashes
    @format = "utf-8"
    @process = (code) =>
      code = uglifyjs(code,@js_opts).code.toString() if @compress unless @path.match /\.min\./
      console.log "[" + "js".blue + "] " + @path.basename().yellow if @verbose
      @buffer = code
      @child_ready()
    return "XXX#{@id}XXX"

  coffee : =>
    @path = @path.replace /.js$/, '.coffee'
    util.print "c".yellow if @hashes
    @format = "utf-8"
    @process = (code) =>
      code = coffee.compile code.toString("utf-8")
      code = uglifyjs(code,@js_opts).code.toString() if @compress unless @path.match /\.min\./
      console.log "[" + "coffee".blue + "] " + @path.basename().yellow if @verbose
      @buffer = code
      @child_ready()
    return "XXX#{@id}XXX"

  file_fetch : =>
    # console.log "[" + "get_local".yellow + "] " + @path + " " + @type.blue # if @debug
    fs.readFile @path, @format, (err,data) =>
      return @join console.error "Failed reading local file #{@path}" if err
      # console.log "[" + "local".green + "] " + @path if @verbose
      @process data

  http_fetch : =>
    console.log "[" + "fetch".red + "] " + @path
    buf = ""
    protocol = if @path.indexOf("https") is 0 then https else http
    opts = url.parse(@path)
    opts.headers = { "user-agent" : UA_CHROME }
    get = protocol.get opts, (res) =>
      res.on "data", (data) =>
        buf += data.toString(@format)
      res.on "end",  (data) =>
        buf += data.toString(@format) if data? and typeof data is "string"
        @on_ready = (buf) =>
          # console.log "[" + "cached".green + "] " + @path if @verbose
          fs.writeFile @hash, buf, (err)-> console.error err if err?
        @process buf
    get.on "error", =>
      @child_ready console.error "Failed reading remote: " + @path

  child_ready : (id) ->
    util.print "#".green if @hashes;                   # console.log "child_ready".red + " " + @path.basename()
    for k,v of @child when v.invalid? # remove failed children
      console.warn "[#{"MISSING".red}] #{@child[k].path.yellow}" if @warn_missing
      delete @child[k]
    for k,v of @child when !v.is_ready                 # abort unless no more open childs
      return # ( console.log "still waiting for #{v.path.red}" if @parent.top? )
    @result = @buffer.toString()
    if Object.keys(@child).length > 0
      util.print (if @hashes then " " else "") + "[" + "assemble".yellow + ":" + @path.blue + "]" + (if @verbose then "\n" else "") if @verbose or @hashes
      for k,v of @child
        return (console.log "Unexpected not ready: #{v.path}") if v.is_ready is no
        if typeof v.result is "string"
          # console.log "using result for #{v.placeholder} = #{v.result.substring(0,20)} #{@result.indexOf(v.placeholder)}"
          @result = @result.replace v.placeholder, v.result
        else
          # console.log "using buffer for #{v.path}"
          @result = @result.replace v.placeholder, v.buffer
    # console.log "[" + "ready".green + "] " + @path if @verbose
    @is_ready = true
    @on_ready(@result) if typeof @on_ready is "function" 
    @parent.child_ready @result

module.exports = htx
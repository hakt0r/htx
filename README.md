## htx - website compiler / compressor

### Installation
    $ sudo npm install -g git://github.com/hakt0r/htx.git

### CLI usage
  $ htx -w WEBROOT -t TEMPLATE.html -d /path/to/output
  * -w : define WEBROOT
  * -t : define TEMPLATE, realtive to WEBROOT
  * -d : path to OUTPUT FILE, can be outside of WEBROOT
  * -R : recompile if asset is changed
  * -W : warn of missing assets
  * -v : be verbose
  * -H : draw hashes
  * -D : debug

### Node.JS Usage:
    htx = require('htx')
    t = htx({
        "webroot" : "/var/www.tpl",
        "template" : "index.html",
        "dest" : "/var/www/index.html",
        "recompile" : true
    })

### Copyrights and License
  * c) 2013 Sebastian Glaser <anx@ulzq.de>
  * Licensed under GNU GPLv3

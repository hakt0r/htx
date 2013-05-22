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
        "webroot"   : "/var/www.tpl",
        "template"  : "index.html",
        "dest"      : "/var/www/index.html",
        "recompile" : true
    })

### Copyrights
  * c) 2013 Sebastian Glaser <anx@ulzq.de>

### Licensed under GNU GPLv3

htx is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2, or (at your option)
any later version.

htx is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this software; see the file COPYING.  If not, write to
the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
Boston, MA 02111-1307 USA

http://www.gnu.org/licenses/gpl.html
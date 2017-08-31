#!/bin/bash
#
#           Provided By The SliTaz Development Team.
#          Copyright (C) 2017 The SliTaz Association.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# @@ Turbine Database.
. /var/www/cgi-bin/turbine/res/base/data
. /var/www/cgi-bin/turbine/res/template/scheme

case "$(GET)" in
  img)
    header "HTTP/1.1 200 OK\nContent-type: image/png"
    case "$(GET img)" in
      lg) cat $localicons/24/turbine.png ;;
      ani2) cat $localtheme/img/ani-02.png ;;
      ani3) cat $localtheme/img/ani-03.png ;;
      turbine) cat $localicons/256/turbine.png ;;
    esac ;;
  *)
esac

freeMEM(){
  sync && echo 3 > /proc/sys/vm/drop_caches
}

header

appMETAINFO
appFREEUP
appFOOTER
freeMEM
appRETURN

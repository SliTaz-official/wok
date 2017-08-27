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
# @@ Kleanny Scheme File.
. /var/www/cgi-bin/kleanny/res/base/data
. /var/www/cgi-bin/kleanny/res/template/scheme

# @@ Kleanny Cache Status.
source /tmp/kleanny/status.log
STATUS_REPORT="$(du -hcs $CACHES | grep total | sed 's/[*total* ]//g')"

# @@ Page with status info.
header

appMETAINFO

# @@ The cache status situation.
cat <<OUTPUT

<section id="result">
  <div id="scope">
    <div id="coupler"></div>
    <div id="gearONE"></div>
    <div id="gearTWO"></div>
    <p class="status">
      $STATUS_REPORT
    </p>
  </div>
</section>

<form id="cleaner" method="get" action="quit">
  <button type="submit">$(_ "Close")</button>
</form>

OUTPUT

appFOOTER

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

# @@ Kleanny.
source /tmp/kleanny/remove.log

header

appMETAINFO

cleanup

cat <<OUTPUT

<section id="cleanup">
  <div id="scope">
    <div id="coupler"></div>
    <div id="gearONE" class="spin"></div>
    <div id="gearTWO" class="spin"></div>
    <p id="needle"></p>
    <p id="lines"></p>
  </div>
</section>

OUTPUT

appFOOTER
redirect

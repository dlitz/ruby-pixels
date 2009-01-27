#!/usr/bin/env ruby
######################################################################
# invert-image.rb - Invert the colour of an image.
# Copyright (c) 2009 Dwayne C. Litzenberger <dlitz@dlitz.net>
#
# This file is part of Ruby Pixels.
#
# Ruby Pixels is free software: you can redistribute it and/or modify it
# under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ruby Pixels is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with Ruby Pixels.  If not, see
# <http://www.gnu.org/licenses/>.
######################################################################

require 'pixels'

input = Pixels.open_tga("mm/mm-01.tga")
output = Pixels.create_tga("output.tga", input.spec)

input.each_row_rgb do |in_row, y|
  out_row = []
  for r, g, b in in_row
    out_row << [255-r, 255-g, 255-b]
  end
  output.put_row_rgb(y, out_row)
end

output.close
input.close

#!/usr/bin/env ruby
######################################################################
# mean-image.rb - Compute the average (mean) of several input images.
# This allows us to extract the background image from an animation.
#
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

input_filenames = Dir.glob("mm/*.tga")
output_filename = "output.tga"

inputs = input_filenames.map{ |filename| Pixels.open_tga(filename) }
width = inputs[0].width
height = inputs[0].height
output = Pixels.create_tga(output_filename, inputs[0].spec.merge(:origin => :UPPER_LEFT))

puts "Inputs: #{input_filenames.inspect}"
puts "Output: #{output_filename}"
puts "Dimensions: #{width}x#{height}"

# Process the file line-by-line
for y in (0..height-1)
  puts "Processing line #{y+1} of #{height}"
  # Read a line of [r, g, b] values from each input file.
  in_rows = []
  for p in inputs
    in_rows << p.get_row_rgb(y)
  end

  # Generate a line of [r, g, b] values for the output file.
  out_row = []
  for x in (0..width-1)
    # Calculate the mean of all pixel values at this (x, y) location.
    sum_r = 0.0
    sum_g = 0.0
    sum_b = 0.0
    for row in in_rows
      r, g, b = row[x]
      sum_r += r
      sum_g += g
      sum_b += b
    end
    mean_r = sum_r / inputs.length
    mean_g = sum_g / inputs.length
    mean_b = sum_b / inputs.length

    out_row << [mean_r, mean_g, mean_b]
  end

  # Write the line to the output file.
  output.put_row_rgb(y, out_row)
end

# Close the output file
output.close

# Close the input files
inputs.each { |p| p.close }

puts "Output written to #{output_filename}"

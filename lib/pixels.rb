######################################################################
# Author(s)::
#   Dwayne C. Litzenberger (http://www.dlitz.net)
######################################################################
# Copyright::
#   Copyright (c) 2009 Dwayne C. Litzenberger <dlitz@dlitz.net>
# License::
#   This file is part of Ruby Pixels.
#
#   Ruby Pixels is free software: you can redistribute it and/or modify it
#   under the terms of the GNU Lesser General Public License as published
#   by the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   Ruby Pixels is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Lesser General Public License for more details.
#
#   You should have received a copy of the GNU Lesser General Public
#   License along with Ruby Pixels.  If not, see
#   <http://www.gnu.org/licenses/>.
######################################################################
# Homepage:: http://www.dlitz.net/software/ruby-pixels
#
# The TGA format is documented at several places on the web, such as:
# http://local.wasp.uwa.edu.au/~pbourke/dataformats/tga/
#

require 'thread'

#
# Ruby Pixels allows you to read and write RGB/RGBA pixel data stored in
# uncompressed, non-interleaved TGA (Targa) files.
#
# Unlike some other libraries, Ruby Pixels reads and writes one row of pixels
# at a time, you can work with several large images at once without running
# out of memory.
#
# = Requirements
#
# Ruby Pixels needs no external libraries.
#
# = Limitations
#
# Ruby Pixels cannot read or write compressed, interleaved, or colour-mapped
# images.  You may wish to use another tool (e.g. MiniMagick) to convert
# to and from other formats.
#
# Ruby Pixels currently has no support for reading or writing individual
# pixels.  You need to do it on a row-by-row basis.
#
# = Example Code
#
#   # invert-image.rb - Invert the colour of an image.
#   require 'pixels'
#
#   input = Pixels.open_tga("mm/mm-01.tga")
#   output = Pixels.create_tga("output.tga", input.spec)
#
#   input.each_row_rgb do |in_row, y|
#     out_row = []
#     for r, g, b in in_row
#       out_row << [255-r, 255-g, 255-b]
#     end
#     output.put_row_rgb(y, out_row)
#   end
#
#   output.close
#   input.close
#
module Pixels

  VERSION = '0.0.1'

  class DataFormatError < StandardError
  end

  # Open the specified TGA file.
  #
  # file_or_path may be a pathname or a file-like object.  If it is a
  # pathname, it is opened for reading.
  #
  # Returns an instance of one of TargaBase's children (one of Targa15,
  # Targa16, Targa24, or Targa32), depending on the format of the specified
  # file.
  def self.open_tga(file_or_path)
    if file_or_path.respond_to?(:read)
      file = file_or_path
    else
      file = File.open(file_or_path, "rb:binary")
    end

    raw_header = file.read(18)
    h, r = decode_tga_header(raw_header)
    case [h[:bits_per_pixel], r[:alpha_depth]]
    when [16, 0]
      return Targa15.new(file, h, r, 2)
    when [16, 1]
      return Targa16.new(file, h, r, 2)
    when [24, 0]
      return Targa24.new(file, h, r, 3)
    when [32, 0]
      return Targa24.new(file, h, r, 4)
    when [32, 8]
      return Targa32.new(file, h, r, 4)
    else
      raise DataFormatError.new(
        "#{h[:bits_per_pixel]} bpp with #{h[:alpha_depth]}-bit alpha channel not supported")
    end
  end

  # Create a TGA file according to the given specification, and return an
  # instance of one of TargaBase's children (one of Targa15, Targa16, Targa24,
  # or Targa32), depending on the format specification.
  #
  # file_or_path may be a pathname or a file-like object.  If it is a
  # pathname, it is opened for reading.
  #
  # spec is a Hash containing the following keys:
  # [:width]
  #   Width of the image in pixels
  #
  # [:height]
  #   Height of the image in pixels
  #
  # [:color_depth]
  #   Color depth of the image in bits per pixel.  This does not include the
  #   bits used to represent the alpha channel (if any).
  #
  #   Currently, this is always one of [15, 24].
  #
  # [:has_alpha]
  #   If the image has an alpha channel, this is true.  Otherwise, it is
  #   false.  (default false)
  #
  # [:origin]
  #   Specifies which pixel appears first in the TGA file.  Must be one of
  #   :UPPER_LEFT or :LOWER_LEFT.
  #
  #   Note: This only affects the TGA file's internal layout.
  #   get_row_rgb(0) always returns the uppermost row in Ruby Pixels.
  #   (default :UPPER_LEFT)
  def self.create_tga(file_or_path, spec={})
    spec = {
      :width => nil,
      :height => nil,
      :color_depth => nil,
      :has_alpha => false,
      :origin => :UPPER_LEFT,
    }.merge(spec)

    case [spec[:color_depth], !!spec[:has_alpha]]
    when [15, true]
      bpp = 16
      alpha_depth = 1
    when [16, false]
      bpp = 16
      alpha_depth = 0
    when [24, false]
      bpp = 24
      alpha_depth = 0
    when [24, true]
      bpp = 32
      alpha_depth = 8
    else
      raise ArgumentError.new(
        ":depth=#{colour_depth}-bpp with :alpha=#{has_alpha} not supported")
    end

    image_descriptor = alpha_depth
    case spec[:origin]
    when :LOWER_LEFT
      # Do nothing
    when :UPPER_LEFT
      image_descriptor |= 0x20
    else
      raise ArgumentError.new(":origin must be :LOWER_LEFT or :UPPER_LEFT")
    end

    raw_header = [
      0,    # idlength
      0,    # colourmap type
      2,    # data type: Uncompressed RGB(A)
      0,    # colourmap_origin
      0,    # colourmap_length
      0,    # colourmap_depth
      0,    # x_origin
      0,    # y_origin
      spec[:width],
      spec[:height],
      bpp,
      image_descriptor,
    ].pack("CCCvvCvvvvCC")

    h, r = decode_tga_header(raw_header)

    if file_or_path.respond_to?(:write)
      file = file_or_path
    else
      file = File.open(file_or_path, "w+b:binary")
    end

    file.write(raw_header)
    file.seek(0, IO::SEEK_SET)
    return open_tga(file)
  end

  def self.decode_tga_header(raw_header)  #:nodoc:
    h = {}
    h[:idlength], h[:colourmap_type], h[:data_type_code], h[:colourmap_origin],
    h[:colourmap_length], h[:colourmap_depth], h[:x_origin], h[:y_origin],
    h[:width], h[:height], h[:bits_per_pixel], h[:image_descriptor] =
      raw_header.unpack("CCCvvCvvvvCC")

    # Data type
    if h[:data_type_code] != 2
      raise DataFormatError.new(
        "Only uncompressed, unmapped RGB or RGBA data is supported (is this a TGA file?)")
    end

    r = {}
    r[:width] = h[:width]
    r[:height] = h[:height]
    r[:image_data_offset] = 18 + h[:idlength] + h[:colourmap_length]

    r[:bpp] = h[:bits_per_pixel]
    r[:alpha_depth] = h[:image_descriptor] & 0xf
    r[:color_depth] = h[:bits_per_pixel] - r[:alpha_depth]
    r[:origin] = (h[:image_descriptor] & 0x20 != 0) ? :UPPER_LEFT : :LOWER_LEFT

    # Interleaving
    if (h[:image_descriptor] & 0xc0) != 0
      raise DataFormatError.new("Interleaved data not supported")
    end

    return [h, r]
  end

  # Abstract class
  class TargaBase
    # Width of the image (pixels)
    attr_reader :width

    # Height of the image (pixels)
    attr_reader :height

    # Number of bits used to store each pixel
    attr_reader :bpp

    # Color-depth of the image (bits per pixel)
    attr_reader :color_depth

    # Bit-depth of the alpha channel (bits per pixel)
    attr_reader :alpha_depth

    # Indicates which pixel appears first in the TGA file.
    # One of :UPPER_LEFT or :LOWER_LEFT.
    attr_reader :origin

    # Do not instantiate this object directly.  Use from_file.
    def initialize(file, header, instance_vars, bytes_per_pixel)
      @mutex = Mutex.new    # Obtain this lock whenever you use @file
      @file = file
      @header = header
      for k, v in instance_vars
        instance_variable_set("@#{k.to_s}", v)
      end
      @bytes_per_pixel = bytes_per_pixel
      @bytes_per_row = bytes_per_pixel * @width
    end

    # Return a Hash containing the file format specification, which can be used as the "spec"
    # parameter in Pixels::create_tga.
    def spec
      return {
        :width => width,
        :height => height,
        :color_depth => color_depth,
        :has_alpha => has_alpha?,
        :origin => origin,
      }
    end

    # Return a string containing the raw bytes from the row at the
    # specified y-coordinate.
    #
    # You probably want to use get_row_rgb or get_row_rgba instead.
    def read_row_bytes(y)
      @mutex.synchronize {
        @file.seek(row_offset(y), IO::SEEK_SET)
        return @file.read(@bytes_per_row)
      }
    end

    # Write a string containing the raw bytes for a row Return a string containing the raw bytes from the row at the
    # specified y-coordinate.
    #
    # You probably want to use put_row_rgb or put_row_rgba instead.
    def write_row_bytes(y, raw_data)
      if raw_data.length != @bytes_per_row
        raise ArgumentError.new("raw_data.length was #{raw_data.length}, expected #{@bytes_per_row}")
      end
      @mutex.synchronize {
        @file.seek(row_offset(y), IO::SEEK_SET)
        return @file.write(raw_data)
      }
    end

    # Close the underlying file.
    def close
      @mutex.synchronize {
        @file.close
        @file = nil
        @mutex = nil
      }
    end

    # Iterate through each row of the image, representing each pixel as an RGB
    # value.
    #
    # For each y-coordinate in the image, this method calls the given block
    # with two arguments: get_row_rgb(y) and y.
    #
    # If no block is provided, an Enumerator is returned.
    def each_row_rgb
      return Enumerable::Enumerator.new(self, :each_row_rgb) unless block_given?
      for y in (0..@height-1)
        yield get_row_rgb(y), y
      end
    end

    # Iterate through each row of the image, representing each pixel as an
    # RGBA value.
    #
    # For each y-coordinate in the image, this method calls the given block
    # with two arguments: get_row_rgba(y) and y.
    #
    # If no block is provided, an Enumerator is returned.
    def each_row_rgba
      return Enumerable::Enumerator.new(self, :each_row_rgba) unless block_given?
      for y in (0..@height-1)
        yield get_row_rgba(y), y
      end
    end

    # Return the row of pixels having the specified y-coordinate.  The row is
    # represented as an array of [r, g, b] values for each pixel in the row.
    #
    # Each r, g, b value is an integer between 0 and 255.
    def get_row_rgb(y)
      return get_row(y).map { |color| rgb_from_color(color) }
    end

    # Return the row of pixels having the specified y-coordinate.  The row is
    # represented as an array of [r, g, b, a] values for each pixel in the row.
    #
    # Each r, g, b, a value is an integer between 0 and 255.
    def get_row_rgba(y)
      return get_row(y).map { |color| rgba_from_color(color) }
    end

    # Replace the row of pixels having the specified y-coordinate.  The row is
    # represented as an array of [r, g, b] values for each pixel in the row.
    #
    # Each r, g, b value is an integer between 0 and 255.
    def put_row_rgb(y, row_rgb)
      return put_row(y, row_rgb.map { |r, g, b| color_from_rgb(r, g, b) })
    end

    # Replace the row of pixels having the specified y-coordinate.  The row is
    # represented as an array of [r, g, b, a] values for each pixel in the row.
    #
    # Each r, g, b, a value is an integer between 0 and 255.
    def put_row_rgba(y, row_rgba)
      return put_row(y, row_rgba.map { |r, g, b, a| color_from_rgba(r, g, b, a) })
    end

    protected

    # Return the offset in the file where the specified row can be found.
    def row_offset(y)
      if y < 0 or y >= @height
        raise ArgumentError.new("y-coordinate #{y} out of range")
      end

      # Flip the vertical axis when (0, 0) is in the lower-left
      # corner of the image.
      if @origin == :LOWER_LEFT
        y = (@height-1) - y
      end

      return @image_data_offset + @bytes_per_row * y
    end
  end

  # Mix-in module for image types having no alpha channel.
  #
  # It makes has_alpha? return false, and it emulates rgba_from_color and
  # color_from_rgba.
  module NoAlphaChannel

    # Return true of the image has an alpha channel.  Otherwise, return false.
    def has_alpha?
      false
    end

    # Given an integer colour value, return separate [r, g, b, 255] values.
    #
    # This is a wrapper around rgb_from_color.  The alpha channel is always
    # set fully opaque.
    def rgba_from_color(color)
      return rgb_from_color(color) + [255]
    end

    # Given separate [r, g, b, a] values, return the integer colour value.
    #
    # This is a wrapper around color_from_rgb.  The alpha channel is ignored.
    def color_from_rgba(r, g, b, a)
      return color_from_rgb(r, g, b)
    end
  end

  # Mix-in module for image types having an alpha channel.
  #
  # It makes has_alpha? return true, and it emulates rgb_from_color and
  # color_from_rgb.
  module HasAlphaChannel
    # Return true of the image has an alpha channel.  Otherwise, return false.
    def has_alpha?
      true
    end

    # Given an integer colour value, return separate [r, g, b] values.
    #
    # This is a wrapper around rgba_from_color.  The alpha channel is ignored.
    def rgb_from_color(color)
      return rgba_from_color(color)[0..2]
    end

    # Given separate [r, g, b] values, return the integer colour value.
    #
    # This is a wrapper around color_from_rgba.  The alpha channel is always
    # set fully opaque.
    def color_from_rgb(r, g, b)
      return color_from_rgba(r, g, b, 255)
    end
  end

  class Targa15 < TargaBase
    include NoAlphaChannel

    # You probably want to use TargaBase#get_row_rgb or TargaBase#get_row_rgba instead.
    def get_row(y)
      bytes = read_row_bytes(y)
      row = []
      for offset in (0..@width*@bytes_per_pixel-1).step(@bytes_per_pixel)
        v, = bytes[offset,2].unpack("v")
        row << (v & 0x7fff)
      end
      return row
    end

    # You probably want to use TargaBase#put_row_rgb or TargaBase#put_row_rgba instead.
    def put_row(y, row)
      bytes = row.pack("v" * row.length)
      write_row_bytes(y, bytes)
    end

    # Given a 15-bit integer colour value, return separate [r, g, b] values.
    #
    # Each r, g, b value is an integer between 0 and 255.
    def rgb_from_color(color)
      # Extract 5 bits-per-channel values
      b5 = color & 0x1f
      g5 = (color >> 5) & 0x1f
      r5 = (color >> 10) & 0x1f

      # Convert 5 bits-per-channel to 8 bits-per-channel
      r8 = r5 * 255 / 31
      g8 = g5 * 255 / 31
      b8 = b5 * 255 / 31
      return [r, g, b]
    end

    # Return a 15-bit integer pixel value given separate red, green, and blue values.
    #
    # Each r, g, b value is an integer between 0 and 255.
    def color_from_rgb(r, g, b)
      # Convert 8 bits-per-channel to 5 bits-per-channel
      r5 = (r.to_i >> 3) & 0x1f
      g5 = (g.to_i >> 3) & 0x1f
      b5 = (b.to_i >> 3) & 0x1f
      return (b5 << 10) | (g5 << 5) | r5
    end
  end

  class Targa16 < TargaBase
    include HasAlphaChannel

    # You probably want to use TargaBase#get_row_rgb or TargaBase#get_row_rgba instead.
    def get_row(y)
      bytes = read_row_bytes(y)
      row = []
      for offset in (0..@width*@bytes_per_pixel-1).step(@bytes_per_pixel)
        v, = bytes[offset,2].unpack("v")
        row << v
      end
      return row
    end

    # You probably want to use TargaBase#put_row_rgb or TargaBase#put_row_rgba instead.
    def put_row(y, row)
      bytes = row.pack("v" * row.length)
      write_row_bytes(y, bytes)
    end

    # Given a 16-bit integer colour value, return separate [r, g, b, a] values.
    #
    # Each r, g, b, a value is an integer between 0 and 255.
    def rgba_from_color(color)
      # Extract 5 bits-per-channel values
      b5 = color & 0x1f
      g5 = (color >> 5) & 0x1f
      r5 = (color >> 10) & 0x1f
      a1 = (color >> 15) & 1

      # Convert 5 bits-per-channel to 8 bits-per-channel
      r8 = r5 * 255 / 31
      g8 = g5 * 255 / 31
      b8 = b5 * 255 / 31
      a8 = (a1 > 0) ? 255 : 0
      return [r8, g8, b8, a8]
    end

    # Return a 16-bit integer pixel value given separate red, green, blue, and alpha values.
    #
    # Each r, g, b, a value is an integer between 0 and 255.
    def color_from_rgba(r, g, b, a)
      # Convert 8 bits-per-channel to 5 bits-per-channel
      r5 = (r.to_i >> 3) & 0x1f
      g5 = (g.to_i >> 3) & 0x1f
      b5 = (b.to_i >> 3) & 0x1f
      a1 = (a.to_i >> 7) & 1
      return (a1 << 15) | (b5 << 10) | (g5 << 5) | r5
    end
  end

  class Targa24 < TargaBase
    include NoAlphaChannel

    # You probably want to use TargaBase#get_row_rgb or TargaBase#get_row_rgba instead.
    def get_row(y)
      bytes = read_row_bytes(y)
      row = []
      for offset in (0..@width*@bytes_per_pixel-1).step(@bytes_per_pixel)
        v, = (bytes[offset,3] + "\x00").unpack("V")
        row << (v & 0x00ffffff)
      end
      return row
    end

    # You probably want to use TargaBase#put_row_rgb or TargaBase#put_row_rgba instead.
    def put_row(y, row)
      bytes = row.map{|v| [v].pack("V")[0..2]}.join
      write_row_bytes(y, bytes)
    end

    # Given a 24-bit integer colour value, return separate [r, g, b] values.
    #
    # Each r, g, b value is an integer between 0 and 255.
    def rgb_from_color(color)
      # Extract 8-bit-per-channel values
      b = color & 0xff
      g = (color >> 8) & 0xff
      r = (color >> 16) & 0xff
      return [r, g, b]
    end

    # Return a 24-bit integer pixel value given separate red, green, and blue values.
    #
    # Each r, g, b value is an integer between 0 and 255.
    def color_from_rgb(r, g, b)
      # Pack 8-bit-per-channel values
      return ((r.to_i & 0xff) << 16) |
             ((g.to_i & 0xff) << 8) |
             (b.to_i & 0xff)
    end
  end

  class Targa32 < TargaBase
    include HasAlphaChannel

    # You probably want to use TargaBase#get_row_rgb or TargaBase#get_row_rgba instead.
    def get_row(y)
      bytes = read_row_bytes(y)
      row = []
      for offset in (0..@width*@bytes_per_pixel-1).step(@bytes_per_pixel)
        row += bytes[offset,4].unpack("V")
      end
      return row
    end

    # You probably want to use TargaBase#put_row_rgb or TargaBase#put_row_rgba instead.
    def put_row(y, row)
      bytes = row.pack("V" * row.length)
      write_row_bytes(y, bytes)
    end

    # Given a 16-bit integer colour value, return separate [r, g, b, a] values.
    #
    # Each r, g, b, a value is an integer between 0 and 255.
    def rgba_from_color(color)
      # Extract 8-bit-per-channel values
      b = color & 0xff
      g = (color >> 8) & 0xff
      r = (color >> 16) & 0xff
      a = (color >> 24) & 0xff
      return [r, g, b, a]
    end

    # Return a 32-bit integer pixel value given separate red, green, blue, and alpha values.
    #
    # Each r, g, b, a value is an integer between 0 and 255.
    def color_from_rgba(r, g, b, a)
      # Pack 8-bit-per-channel values
      return ((a.to_i & 0xff) << 24) |
             ((r.to_i & 0xff) << 16) |
             ((g.to_i & 0xff) << 8) |
             (b.to_i & 0xff)
    end
  end

end # Targa

# vim:set ts=2 sw=2 sts=2 expandtab:

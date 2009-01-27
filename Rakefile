######################################################################
# Rakefile for Ruby Pixels
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

$LOAD_PATH.unshift("lib")

require 'pixels'
require 'rubygems'

PKG_FILES = FileList['COPYING.*', 'lib/**/*.rb']
RDOC_FILES = FileList['COPYING.*', 'lib/**/*.rb']

spec = Gem::Specification.new do |s|
  s.platform = Gem::Platform::RUBY
  s.name = "ruby-pixels"
  s.version = Pixels::VERSION
  s.summary = "Read and write RGB/RGBA pixel data"
  s.description = <<EOF
Ruby Pixels allows you to read and write RGB/RGBA pixel data stored in
uncompressed TGA (Targa) image files without consuming large amounts of
memory.
EOF
  s.authors = ["Dwayne C. Litzenberger"]
  s.email = ["dlitz@dlitz.net"]
  s.homepage = "http://www.dlitz.net/software/ruby-pixels"
  s.require_path = 'lib'
  s.files = PKG_FILES
  s.has_rdoc = true
  s.rubyforge_project = "ruby-pixels"
end

require 'rake/gempackagetask'
Rake::GemPackageTask.new(spec) do |pkg|
  pkg.need_zip = true
  pkg.need_tar = true
end

require 'rake/rdoctask'
Rake::RDocTask.new do |rd|
  rd.main = "Pixels"
  rd.title = "Ruby Pixels - RDoc Documentation"
  rd.rdoc_files = RDOC_FILES
  rd.options += %w{ --charset UTF-8 --diagram --line-numbers }
end

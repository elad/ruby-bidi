Gem::Specification.new do |s|
  s.name        = "bidi"
  s.version     = "0.0.1"
  s.date        = "2014-11-04"
  s.summary     = "Ruby BiDi"
  s.description = "Bidirectional text library"
  s.authors     = ["Amit Yaron"]
  s.email       = "amit@phpandmore.net"
  s.files       = [
                   "LICENSE",
                   "README.md",
                   "lib/README",
                   "lib/bidi.rb",
                   "lib/bidi/bidi.rb",
                   "lib/bidi/datformirror.rb",
                   "lib/bidi/indexfile.rb",
                   "lib/bidi/weakhashmap.rb",
                   "lib/data/BidiMirroring.dat",
                   "lib/data/BidiMirroring.txt",
                   "lib/data/UnicodeData.idx",
                   "lib/data/UnicodeData.txt"
                  ]
  s.homepage    = "https://github.com/elad/ruby-bidi"
  s.license     = "MIT"
end

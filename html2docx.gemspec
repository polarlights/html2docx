Gem::Specification.new do |spec|
  spec.name        = "html2docx"
  spec.version     = "0.1.0"
  spec.date        = "2014-05-26"
  spec.summary     = "Generate Microsoft Word Office Open XML files"
  spec.description = "Generate and modify Word .docx files programmatically"
  spec.authors     = ["Creeek Hsu", "Mike Gunderloy", "Mike Welham"]
  spec.email       = "creeek.hsu@gmail.com"
  spec.files       = `git ls-files`.split("\n")
  spec.homepage    = "https://github.com/dotxy/html2docx"
  spec.add_dependency("nokogiri", ">= 1.5.2")
  spec.add_dependency("rmagick", ">= 2.12.2")
  spec.add_dependency("rubyzip", ">= 1.0.0")
  spec.add_development_dependency("equivalent-xml", ">= 0.2.9")
  spec.license = "MIT"
end

# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "ruby-openid"
  s.version = "2.3.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["JanRain, Inc"]
  s.autorequire = "openid"
  s.date = "2013-09-14"
  s.email = "openid@janrain.com"
  s.extra_rdoc_files = ["README.md", "INSTALL.md", "LICENSE", "UPGRADE.md"]
  s.files = ["README.md", "INSTALL.md", "LICENSE", "UPGRADE.md"]
  s.homepage = "https://github.com/openid/ruby-openid"
  s.licenses = ["Ruby", "Apache Software License 2.0"]
  s.rdoc_options = ["--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubygems_version = "2.0.14"
  s.summary = "A library for consuming and serving OpenID identities."
end

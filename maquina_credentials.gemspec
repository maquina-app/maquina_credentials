# frozen_string_literal: true

require_relative "lib/maquina_credentials/version"

Gem::Specification.new do |spec|
  spec.name = "maquina_credentials"
  spec.version = Maquina::Credentials::VERSION
  spec.authors = ["Mario Alberto Chávez Cárdenas"]
  spec.email = ["mario.chavez@gmail.com"]

  spec.summary = "Encrypted credentials for the command line"
  spec.description = <<~DESC.tr("\n", " ").strip
    A small, dependency-free gem that encrypts and decrypts a single
    credentials.yml.enc file with AES-256-GCM. Ships an `mcr` command line tool
    for reading and writing values, plus a Ruby API. Designed for container and
    server workflows where the encrypted file travels with the image and the
    master key is injected at runtime via MAQUINA_MASTER_KEY.
  DESC
  spec.homepage = "https://maquina.app"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/maquina-app/maquina_credentials"
  spec.metadata["documentation_uri"] = "https://github.com/maquina-app/maquina_credentials/blob/main/README.md"
  spec.metadata["changelog_uri"] = "https://github.com/maquina-app/maquina_credentials/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/maquina-app/maquina_credentials/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(__dir__) do
    Dir[
      "CHANGELOG.md",
      "CODE_OF_CONDUCT.md",
      "LICENSE.txt",
      "README.md",
      "exe/*",
      "lib/**/*.rb",
      "sig/**/*.rbs"
    ]
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "irb"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "minitest", "~> 5.16"
  spec.add_development_dependency "standard", "~> 1.55"
end

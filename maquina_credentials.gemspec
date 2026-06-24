# frozen_string_literal: true

require_relative "lib/maquina_credentials/version"

Gem::Specification.new do |spec|
  spec.name = "maquina_credentials"
  spec.version = Maquina::Credentials::VERSION
  spec.authors = ["Mario Alberto Chávez"]
  spec.email = ["mario.chavez@gmail.com"]

  spec.summary = "Secure command line credentials"
  spec.description = "Secure command line credentials for encrypting and reading a shared credentials file."
  spec.homepage = "https://maquina.app"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/maquina-app/maquina_credentials.git"
  spec.metadata["changelog_uri"] = "https://github.com/maquina-app/maquina_credentials/blob/main/CHANGELOG.md"

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

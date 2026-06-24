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

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

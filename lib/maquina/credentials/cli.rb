# frozen_string_literal: true

require "optparse"
require "securerandom"
require "shellwords"
require "tempfile"
require "yaml"

module Maquina
  class Credentials
    class CLI
      EDIT_TEMPLATE = <<~YAML
        # Edit your credentials below as YAML, then save and close.
        # Example:
        #   database:
        #     password: s3cret
        #   gh_token: ghp_xxx
      YAML

      def self.start(argv, stdout: $stdout, stderr: $stderr, stdin: $stdin, editor: nil)
        new(argv, stdout: stdout, stderr: stderr, stdin: stdin, editor: editor).run
      end

      def initialize(argv, stdout:, stderr:, stdin:, editor: nil)
        @argv = argv.dup
        @stdout = stdout
        @stderr = stderr
        @stdin = stdin
        @editor = editor || method(:default_editor)
        @credentials_path = nil
      end

      def run
        command = parser.parse!(@argv).first

        case command
        when "help", nil
          @stdout.puts parser
          0
        when "generate"
          generate
        when "read"
          read(@argv[1])
        when "write"
          write
        when "edit"
          edit
        else
          @stderr.puts parser
          command ? 1 : 0
        end
      rescue OptionParser::ParseError => error
        @stderr.puts error.message
        @stderr.puts parser
        1
      rescue MasterKeyMissing
        @stderr.puts "MAQUINA_MASTER_KEY is required"
        1
      rescue DecryptionFailed
        @stderr.puts "Failed to decrypt credentials"
        1
      rescue Psych::Exception
        @stderr.puts "Input must be a valid YAML hash"
        1
      end

      private

      def parser
        @parser ||= OptionParser.new do |options|
          options.banner = <<~TEXT.chomp
            Usage:
              mcr help
              mcr generate
              mcr read KEY [--file PATH]
              mcr write [--file PATH] < credentials.yml
              mcr edit [--file PATH]

            Commands:
              help      Show this help text.
              generate  Print a new random master key to stdout.
              read      Print a credential value to stdout.
              write     Merge YAML from stdin into the credentials file.
              edit      Open the decrypted credentials in $EDITOR, re-encrypt on save.

            File selection:
              Use --file PATH to read or write a specific file.
              Without --file, mcr uses credentials.yml.enc in the current directory.

            Examples:
              mcr generate
              mcr read database.password
              mcr --file /tmp/credentials.yml.enc write < credentials.yml
              mcr edit
              mcr help
          TEXT

          options.on("-f", "--file PATH", "Credentials file path") do |path|
            @credentials_path = path
          end

          options.on("-h", "--help", "Print this help") do
            @stdout.puts options
            exit 0
          end
        end
      end

      def generate
        @stdout.puts SecureRandom.hex(32)
        0
      end

      def read(key)
        unless key
          @stderr.puts "Missing KEY"
          return 1
        end

        @stdout.puts Credentials.new(credentials_path: @credentials_path).read(key)
        0
      end

      def write
        input = @stdin.read
        hash = YAML.safe_load(input, permitted_classes: [], symbolize_names: false)

        unless hash.is_a?(Hash)
          @stderr.puts "Input must be a YAML hash"
          return 1
        end

        Credentials.merge(hash, credentials_path: @credentials_path)
        0
      end

      def edit
        current = Credentials.read_all(credentials_path: @credentials_path)

        Tempfile.create(["mcr-credentials", ".yml"]) do |file|
          file.chmod(0o600)
          file.write(current.empty? ? EDIT_TEMPLATE : YAML.dump(current))
          file.flush

          return 1 unless @editor.call(file.path)

          edited = File.read(file.path)
          hash = YAML.safe_load(edited, permitted_classes: [], symbolize_names: false)

          unless hash.is_a?(Hash)
            @stderr.puts "Edited content must be a YAML hash; no changes saved"
            return 1
          end

          Credentials.write(hash, credentials_path: @credentials_path)
        end

        0
      end

      def default_editor(path)
        command = ENV["EDITOR"] || ENV["VISUAL"]

        if command.nil? || command.empty?
          @stderr.puts "Set $EDITOR or $VISUAL to use mcr edit"
          return false
        end

        system(*Shellwords.split(command), path)
      end
    end
  end
end

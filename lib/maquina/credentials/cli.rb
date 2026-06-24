# frozen_string_literal: true

require "optparse"
require "yaml"

module Maquina
  class Credentials
    class CLI
      def self.start(argv, stdout: $stdout, stderr: $stderr, stdin: $stdin)
        new(argv, stdout: stdout, stderr: stderr, stdin: stdin).run
      end

      def initialize(argv, stdout:, stderr:, stdin:)
        @argv = argv.dup
        @stdout = stdout
        @stderr = stderr
        @stdin = stdin
        @credentials_path = nil
      end

      def run
        command = parser.parse!(@argv).first

        case command
        when "help", nil
          @stdout.puts parser
          0
        when "read"
          read(@argv[1])
        when "write"
          write
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
              mcr read KEY [--file PATH]
              mcr write [--file PATH] < credentials.yml

            Commands:
              help   Show this help text.
              read   Print a credential value to stdout.
              write  Encrypt YAML from stdin and write it to the credentials file.

            File selection:
              Use --file PATH to read or write a specific file.
              Without --file, mcr uses credentials.yml.enc in the current directory.

            Examples:
              mcr read database.password
              mcr --file /tmp/credentials.yml.enc write < credentials.yml
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

        Credentials.write(hash, credentials_path: @credentials_path)
        0
      end
    end
  end
end

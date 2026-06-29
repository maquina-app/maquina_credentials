# frozen_string_literal: true

require "fileutils"
require "openssl"
require "securerandom"
require "yaml"

module Maquina
  class Credentials
    class MasterKeyMissing < StandardError; end
    class DecryptionFailed < StandardError; end

    DEFAULT_CREDENTIALS_PATH = "credentials.yml.enc"
    ENV_KEY = "MAQUINA_MASTER_KEY"
    FILE_ENV_KEY = "MAQUINA_CREDENTIALS_FILE"
    CIPHER = "aes-256-gcm"
    KEY_LENGTH = 32
    IV_LENGTH = 12
    AUTH_TAG_LENGTH = 16
    HKDF_INFO = "maquina-credentials-v1"

    def self.write(hash, credentials_path: nil)
      credentials_path = resolve_credentials_path(credentials_path)
      payload = YAML.dump(deep_stringify(hash))
      encrypted = encrypt(payload, master_key)
      tmp_path = "#{credentials_path}.tmp.#{Process.pid}"

      FileUtils.mkdir_p(File.dirname(credentials_path))
      File.write(tmp_path, encrypted)
      File.rename(tmp_path, credentials_path)
      File.chmod(0o600, credentials_path)
    ensure
      File.delete(tmp_path) if tmp_path && File.exist?(tmp_path)
    end

    def self.merge(hash, credentials_path: nil)
      credentials_path = resolve_credentials_path(credentials_path)
      existing = read_all(credentials_path: credentials_path)
      write(deep_merge(existing, deep_stringify(hash)), credentials_path: credentials_path)
    end

    def self.read_all(credentials_path: nil)
      credentials_path = resolve_credentials_path(credentials_path)
      return {} unless File.exist?(credentials_path)

      decrypted = decrypt(File.read(credentials_path), master_key)
      loaded = YAML.safe_load(decrypted, permitted_classes: [], symbolize_names: false)
      raise DecryptionFailed unless loaded.is_a?(Hash)

      deep_stringify(loaded)
    rescue Psych::Exception
      raise DecryptionFailed
    end

    def self.encrypt(payload, raw_key)
      cipher = OpenSSL::Cipher.new(CIPHER)
      cipher.encrypt
      cipher.key = derive_key(raw_key)
      iv = cipher.random_iv
      cipher.iv = iv
      cipher.auth_data = ""

      ciphertext = cipher.update(payload) + cipher.final
      strict_base64_encode(iv + ciphertext + cipher.auth_tag)
    end

    def self.decrypt(encrypted, raw_key)
      decoded = strict_base64_decode(encrypted)
      raise DecryptionFailed if decoded.bytesize < IV_LENGTH + AUTH_TAG_LENGTH

      iv = decoded.byteslice(0, IV_LENGTH)
      auth_tag = decoded.byteslice(-AUTH_TAG_LENGTH, AUTH_TAG_LENGTH)
      ciphertext = decoded.byteslice(IV_LENGTH, decoded.bytesize - IV_LENGTH - AUTH_TAG_LENGTH)

      cipher = OpenSSL::Cipher.new(CIPHER)
      cipher.decrypt
      cipher.key = derive_key(raw_key)
      cipher.iv = iv
      cipher.auth_tag = auth_tag
      cipher.auth_data = ""
      cipher.update(ciphertext) + cipher.final
    rescue ArgumentError, OpenSSL::Cipher::CipherError
      raise DecryptionFailed
    end

    def self.strict_base64_encode(bytes)
      [bytes].pack("m0")
    end

    def self.strict_base64_decode(encoded)
      unless encoded.match?(/\A(?:[A-Za-z0-9+\/]{4})*(?:[A-Za-z0-9+\/]{2}==|[A-Za-z0-9+\/]{3}=)?\z/)
        raise ArgumentError
      end

      encoded.unpack1("m0")
    end

    def self.derive_key(raw_key)
      raw_key = raw_key.b
      return raw_key[0, KEY_LENGTH] if raw_key.bytesize == KEY_LENGTH

      OpenSSL::KDF.hkdf(
        raw_key,
        salt: "",
        info: HKDF_INFO,
        length: KEY_LENGTH,
        hash: "SHA256"
      )
    end

    def self.master_key
      key = ENV[ENV_KEY]
      raise MasterKeyMissing if key.nil? || key.empty?

      key
    end

    def self.resolve_credentials_path(credentials_path = nil)
      return credentials_path unless credentials_path.nil? || credentials_path.empty?

      env_path = ENV[FILE_ENV_KEY]
      return env_path unless env_path.nil? || env_path.empty?

      File.join(Dir.pwd, DEFAULT_CREDENTIALS_PATH)
    end

    def self.deep_merge(base, override)
      base.merge(override) do |_key, base_value, override_value|
        if base_value.is_a?(Hash) && override_value.is_a?(Hash)
          deep_merge(base_value, override_value)
        else
          override_value
        end
      end
    end

    def self.deep_stringify(obj)
      case obj
      when Hash
        obj.transform_keys(&:to_s).transform_values { |value| deep_stringify(value) }
      when Array
        obj.map { |value| deep_stringify(value) }
      else
        obj
      end
    end

    def initialize(credentials_path: nil)
      @credentials_path = self.class.resolve_credentials_path(credentials_path)
      @credentials = nil
      @loaded = false
    end

    def read(path)
      return "" if path.nil? || path.empty?

      value = path.split(".").reduce(credentials) do |current, key|
        break unless current.is_a?(Hash)

        current[key]
      end

      value.nil? ? "" : value.to_s
    end

    private

    attr_reader :credentials_path

    def credentials
      return @credentials if @loaded

      @credentials = load_credentials
      @loaded = true
      @credentials
    end

    def load_credentials
      self.class.read_all(credentials_path: credentials_path)
    end
  end
end

# frozen_string_literal: true

require "fileutils"
require "stringio"
require "tmpdir"

require "test_helper"
require "maquina/credentials/cli"

class TestMaquinaCredentials < Minitest::Test
  MASTER_KEY = "test-master-key"
  OTHER_MASTER_KEY = "other-test-master-key"

  def setup
    @original_master_key = ENV["MAQUINA_MASTER_KEY"]
    @original_credentials_file = ENV["MAQUINA_CREDENTIALS_FILE"]
    @tmpdir = Dir.mktmpdir
    @credentials_path = File.join(@tmpdir, "credentials.yml.enc")
  end

  def teardown
    ENV["MAQUINA_MASTER_KEY"] = @original_master_key
    ENV["MAQUINA_CREDENTIALS_FILE"] = @original_credentials_file
    FileUtils.remove_entry(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
  end

  def test_that_it_has_a_version_number
    refute_nil ::Maquina::Credentials::VERSION
  end

  def test_read_with_present_key
    write_credentials("api_key" => "secret")

    assert_equal "secret", credentials.read("api_key")
  end

  def test_read_with_absent_key
    write_credentials("api_key" => "secret")

    assert_equal "", credentials.read("missing")
  end

  def test_read_with_nil
    assert_equal "", credentials.read(nil)
  end

  def test_read_with_empty_string
    assert_equal "", credentials.read("")
  end

  def test_read_with_dot_path
    write_credentials("database" => {"password" => "prod-secret"})

    assert_equal "prod-secret", credentials.read("database.password")
  end

  def test_read_with_integer_key_in_yaml
    write_credentials(2024 => "year-secret")

    assert_equal "year-secret", credentials.read("2024")
  end

  def test_missing_file_returns_empty_string_without_master_key
    ENV.delete("MAQUINA_MASTER_KEY")

    assert_equal "", credentials.read("anything")
    assert_equal "", credentials.read("again")
  end

  def test_default_path_uses_current_working_directory
    Dir.chdir(@tmpdir) do
      assert_equal File.join(Dir.pwd, "credentials.yml.enc"), Maquina::Credentials.resolve_credentials_path
    end
  end

  def test_env_path_is_used_when_no_explicit_path
    env_path = File.join(@tmpdir, "from-env.yml.enc")
    ENV["MAQUINA_CREDENTIALS_FILE"] = env_path

    assert_equal env_path, Maquina::Credentials.resolve_credentials_path
  end

  def test_explicit_path_wins_over_env_path
    explicit_path = File.join(@tmpdir, "explicit.yml.enc")
    ENV["MAQUINA_CREDENTIALS_FILE"] = File.join(@tmpdir, "from-env.yml.enc")

    assert_equal explicit_path, Maquina::Credentials.resolve_credentials_path(explicit_path)
  end

  def test_missing_master_key_raises_when_file_exists
    write_credentials("api_key" => "secret")
    ENV.delete("MAQUINA_MASTER_KEY")

    assert_raises(Maquina::Credentials::MasterKeyMissing) do
      credentials.read("api_key")
    end
  end

  def test_wrong_key_raises_decryption_failed
    write_credentials("api_key" => "secret")
    ENV["MAQUINA_MASTER_KEY"] = OTHER_MASTER_KEY

    assert_raises(Maquina::Credentials::DecryptionFailed) do
      credentials.read("api_key")
    end
  end

  def test_malformed_base64_raises_decryption_failed
    ENV["MAQUINA_MASTER_KEY"] = MASTER_KEY
    write_file("not base64!!")

    assert_raises(Maquina::Credentials::DecryptionFailed) do
      credentials.read("api_key")
    end
  end

  def test_truncated_payload_raises_decryption_failed
    ENV["MAQUINA_MASTER_KEY"] = MASTER_KEY
    write_file(strict_base64_encode("short"))

    assert_raises(Maquina::Credentials::DecryptionFailed) do
      credentials.read("api_key")
    end
  end

  def test_tampered_ciphertext_raises_decryption_failed
    write_credentials("api_key" => "secret")
    bytes = strict_base64_decode(File.read(@credentials_path)).bytes
    bytes[Maquina::Credentials::IV_LENGTH] ^= 1
    write_file(strict_base64_encode(bytes.pack("C*")))

    assert_raises(Maquina::Credentials::DecryptionFailed) do
      credentials.read("api_key")
    end
  end

  def test_unsafe_yaml_raises_decryption_failed
    ENV["MAQUINA_MASTER_KEY"] = MASTER_KEY
    encrypted = Maquina::Credentials.encrypt("--- !ruby/object:Object {}\n", MASTER_KEY)
    write_file(encrypted)

    assert_raises(Maquina::Credentials::DecryptionFailed) do
      credentials.read("api_key")
    end
  end

  def test_round_trip_write_read
    write_credentials("api_key" => "secret", "nested" => {"token" => "abc"})

    assert_equal "secret", credentials.read("api_key")
    assert_equal "abc", credentials.read("nested.token")
  end

  def test_iv_is_unique_across_writes
    write_credentials("api_key" => "one")
    first_iv = iv_from_file
    write_credentials("api_key" => "two")
    second_iv = iv_from_file

    refute_equal first_iv, second_iv
  end

  def test_written_iv_is_not_all_zeroes
    write_credentials("api_key" => "secret")

    refute_equal "\x00".b * Maquina::Credentials::IV_LENGTH, iv_from_file
  end

  def test_file_permissions_are_0600
    write_credentials("api_key" => "secret")

    assert_equal 0o600, File.stat(@credentials_path).mode & 0o777
  end

  def test_atomic_write_failure_cleans_temp_file_and_preserves_original
    write_credentials("api_key" => "original")
    original = File.read(@credentials_path)
    original_rename = File.method(:rename)

    redefine_without_warning(File, :rename) do |*_args|
      raise Errno::EACCES, "simulated rename failure"
    end

    assert_raises(Errno::EACCES) do
      Maquina::Credentials.write({"api_key" => "new"}, credentials_path: @credentials_path)
    end

    assert_equal original, File.read(@credentials_path)
    assert_empty Dir.glob("#{@credentials_path}.tmp.*")
  ensure
    redefine_without_warning(File, :rename, original_rename) if original_rename
  end

  def test_instance_caches_decrypted_result
    write_credentials("api_key" => "secret")
    decrypt_count = 0
    original_decrypt = Maquina::Credentials.method(:decrypt)

    redefine_without_warning(Maquina::Credentials, :decrypt) do |encrypted, raw_key|
      decrypt_count += 1
      original_decrypt.call(encrypted, raw_key)
    end

    reader = credentials
    assert_equal "secret", reader.read("api_key")
    assert_equal "secret", reader.read("api_key")
    assert_equal 1, decrypt_count
  ensure
    redefine_without_warning(Maquina::Credentials, :decrypt, original_decrypt) if original_decrypt
  end

  def test_cli_write_reads_yaml_from_stdin
    ENV["MAQUINA_MASTER_KEY"] = MASTER_KEY
    stdin = StringIO.new("api_key: cli-secret\n")

    assert_equal 0, run_cli(["--file", @credentials_path, "write"], stdin: stdin)
    assert_equal "cli-secret", credentials.read("api_key")
  end

  def test_cli_read_writes_value_to_stdout
    write_credentials("api_key" => "cli-secret")
    stdout = StringIO.new

    assert_equal 0, run_cli(["--file", @credentials_path, "read", "api_key"], stdout: stdout)
    assert_equal "cli-secret\n", stdout.string
  end

  def test_cli_uses_env_credentials_file
    ENV["MAQUINA_MASTER_KEY"] = MASTER_KEY
    ENV["MAQUINA_CREDENTIALS_FILE"] = @credentials_path
    assert_equal 0, run_cli(["write"], stdin: StringIO.new("api_key: env-secret\n"))

    stdout = StringIO.new
    assert_equal 0, run_cli(["read", "api_key"], stdout: stdout)
    assert_equal "env-secret\n", stdout.string
  end

  def test_cli_uses_current_working_directory_when_file_is_not_specified
    ENV["MAQUINA_MASTER_KEY"] = MASTER_KEY
    Dir.chdir(@tmpdir) do
      assert_equal 0, run_cli(["write"], stdin: StringIO.new("api_key: pwd-secret\n"))

      stdout = StringIO.new
      assert_equal 0, run_cli(["read", "api_key"], stdout: stdout)
      assert_equal "pwd-secret\n", stdout.string
    end
  end

  def test_cli_rejects_non_hash_yaml
    stderr = StringIO.new

    assert_equal 1, run_cli(["--file", @credentials_path, "write"], stdin: StringIO.new("- nope\n"), stderr: stderr)
    assert_match(/YAML hash/, stderr.string)
  end

  private

  def credentials
    Maquina::Credentials.new(credentials_path: @credentials_path)
  end

  def write_credentials(hash)
    ENV["MAQUINA_MASTER_KEY"] = MASTER_KEY
    Maquina::Credentials.write(hash, credentials_path: @credentials_path)
  end

  def write_file(contents)
    FileUtils.mkdir_p(File.dirname(@credentials_path))
    File.write(@credentials_path, contents)
  end

  def iv_from_file
    strict_base64_decode(File.read(@credentials_path)).byteslice(0, Maquina::Credentials::IV_LENGTH)
  end

  def strict_base64_encode(bytes)
    [bytes].pack("m0")
  end

  def strict_base64_decode(encoded)
    encoded.unpack1("m0")
  end

  def redefine_without_warning(object, method_name, method_object = nil, &block)
    original_verbose = $VERBOSE
    $VERBOSE = nil
    method_object ? object.define_singleton_method(method_name, method_object) : object.define_singleton_method(method_name, &block)
  ensure
    $VERBOSE = original_verbose
  end

  def run_cli(argv, stdin: StringIO.new, stdout: StringIO.new, stderr: StringIO.new)
    Maquina::Credentials::CLI.start(argv, stdin: stdin, stdout: stdout, stderr: stderr)
  end
end

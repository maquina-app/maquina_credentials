# Maquina Credentials

Encrypt and decrypt a single `credentials.yml.enc` file with AES-256-GCM.

`maquina_credentials` is a small, dependency-free gem for storing secrets in an
encrypted file that can safely travel with your source or container image. The
master key never lives in the file — it is supplied at runtime through the
`MAQUINA_MASTER_KEY` environment variable. Reading a missing key returns an
empty string and never raises, so it is safe to call in code paths that may run
without credentials configured.

It is inspired by Rails' encrypted credentials, distilled down to a single file,
a command line tool, and a plain Ruby API — with no dependency on Rails or
Active Support.

## Installation

Add it to your `Gemfile`:

```ruby
gem "maquina_credentials"
```

Then run `bundle install`. Or install it directly:

```sh
gem install maquina_credentials
```

Requires Ruby >= 3.2.0.

## Master key

Generate a master key once and store it as a secret (never commit it):

```sh
mcr generate
```

This prints a fresh random key built from `SecureRandom.hex(32)`. If you do not
have the executable handy, the equivalent in plain Ruby is:

```sh
ruby -e "require 'securerandom'; puts SecureRandom.hex(32)"
```

Provide the key to every command through `MAQUINA_MASTER_KEY`. Any 32-byte key
is used directly; keys of any other length (including the 64-character hex
string above) are run through HKDF-SHA256 to derive the encryption key.

## Command line

The gem installs an `mcr` executable.

Read a value (dot-paths traverse nested keys):

```sh
MAQUINA_MASTER_KEY=<key> mcr read database.password
```

Write credentials from piped YAML:

```sh
MAQUINA_MASTER_KEY=<key> printf "database:\n  password: prod-secret\n" | mcr write
```

Use a specific encrypted file:

```sh
mcr --file /path/to/credentials.yml.enc read database.password
```

Generate a new master key:

```sh
mcr generate
```

Show help:

```sh
mcr help
```

### File selection

The encrypted file is resolved in this order:

1. The `--file PATH` option, when given.
2. The `MAQUINA_CREDENTIALS_FILE` environment variable.
3. `credentials.yml.enc` in the current working directory.

## Ruby API

The same class is available through `require "maquina_credentials"`.

```ruby
credentials = Maquina::Credentials.new
credentials.read("anthropic_key")
credentials.read("database.password")  # dot-path traversal

# Writing replaces the whole file from a full hash:
Maquina::Credentials.write({
  anthropic_key: "sk-ant-...",
  database: {password: "prod-secret"}
})
```

- Missing credential paths return an empty string (`""`), never `nil`.
- All values are returned as strings.
- A missing or empty `MAQUINA_MASTER_KEY` raises
  `Maquina::Credentials::MasterKeyMissing` (only when a credentials file
  actually exists).
- A wrong key, tampered, truncated, or otherwise unreadable file raises
  `Maquina::Credentials::DecryptionFailed`.
- An instance decrypts once and caches the result for the life of the object.

## Security notes

- Cipher is AES-256-GCM; the wire format is strict-base64 of
  `IV (12 bytes) || ciphertext || GCM auth tag (16 bytes)`.
- A fresh random IV is generated on every write.
- Writes are atomic (temp file renamed into place) and the file is set to mode
  `0600`.
- YAML is parsed with `safe_load(permitted_classes: [])` on both read and write,
  so a tampered file cannot instantiate arbitrary Ruby objects.

## Container workflow

```sh
# 1. Generate the master key once and store it as a secret.
mcr generate

# 2. Write credentials locally.
MAQUINA_MASTER_KEY=<key> printf "anthropic_key: sk-ant-...\n" | mcr write

# 3. Commit credentials.yml.enc into the image — the key never goes in.
docker build -t my-app .

# 4. Inject the key at runtime (or via orchestrator secrets).
docker run -e MAQUINA_MASTER_KEY=<key> my-app
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run
`bundle exec rake` to run the tests and Standard Ruby. Use `bin/console` for an
interactive prompt with the gem preloaded.

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

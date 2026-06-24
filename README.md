# Secure command line credentials

Encrypt and decrypt a single `credentials.yml.enc` file with AES-256-GCM.

## Command Line

The gem installs an `mcr` executable.

Read a value:

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

When `--file` is omitted, the executable uses `MAQUINA_CREDENTIALS_FILE`. If that is not set, it uses `credentials.yml.enc` under the current working directory.

## Ruby API

If you need direct access from Ruby, the same class is available through `require "maquina_credentials"`.

```ruby
credentials = Maquina::Credentials.new
credentials.read("anthropic_key")
credentials.read("database.password")
```

Missing credential paths return an empty string. Missing `MAQUINA_MASTER_KEY` or unreadable encrypted content raises a `Maquina::Credentials` error.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then run `bundle exec rake` to run tests and Standard Ruby.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

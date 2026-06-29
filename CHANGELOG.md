## [Unreleased]

## [0.2.0] - 2026-06-28

- `mcr write` now **merges** the YAML from stdin into the existing credentials
  file instead of replacing the whole file. Existing keys are preserved, nested
  hashes are deep-merged, and scalar values are overwritten.
- Added `mcr edit`, which decrypts the credentials into a temporary file, opens
  it in `$EDITOR` (or `$VISUAL`), and re-encrypts on save. Editing replaces the
  full document, so removing a key in the editor removes it from the file.
- Added `Maquina::Credentials.merge` and `Maquina::Credentials.read_all` to the
  Ruby API.

## [0.1.0] - 2026-06-24

- Initial release
- Encrypt and decrypt a `credentials.yml.enc` file with AES-256-GCM
- `mcr` command line tool with `generate`, `read`, and `write` commands
- Ruby API via `Maquina::Credentials`

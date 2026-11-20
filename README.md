# REST API test suite for remoteStorage servers

This Ruby suite exercises the [remoteStorage HTTP API](https://datatracker.ietf.org/doc/draft-dejong-remotestorage/)
against a running server. It supports draft-specific checks from 03 through 27.

## Requirements

- `ruby 2.6` or `2.7` and `bundler` installed on your OS
- A remoteStorage test account with no data in it, and three tokens
  for that account: one with read/write access to a category (such as
  `api-test`), one with read-only access to that category, and one with
  read/write access to all categories (root access) (Hint: The [example
  app](https://github.com/remotestorage/armadietto/tree/master/example) in
  the Armedietto repository can help you generate these.)
- Another account on the server (which can have any data in it,
  and which won't be altered by a successful test).

## Usage

- Copy `config.yml.example` to `config.yml` and edit the required values/tokens
- `bundle install`
- `rake test`

## Selecting a draft

Set `draft_version` in `config.yml` to the draft you want to test, for example
`22` or `27`. Quote a zero-padded number such as `"09"` to keep it a string.

To test discovery, set `webfinger_url` to the complete WebFinger request URL
for the test account, including its encoded `resource` query parameter.
With that setting alone, the suite uses the version advertised for
`storage_base_url`. With both settings, the two versions must agree. Discovery
sends no bearer token. Storage requests still use the configured base URL.
Existing configs with neither setting keep the unversioned checks.

| Starting draft | Additional or changed checks |
| --- | --- |
| 06 | `Cache-Control: no-cache` replaces `Expires: 0`. Check missing credentials (401), insufficient scope (403), anonymous HEAD of a public document, wildcard CORS origins and rejection of partial PUTs. Exercise partial and unsatisfiable GETs when byte ranges are advertised. |
| 11 | Each document in a folder listing has an HTTP-date in `Last-Modified`. |
| 12 | A listing cannot contain both a document and a folder with the same name. The suite also tests both conflicting PUT directions. |
| 26–27 | GETs in the public subtree include both `no-cache` and `public`. With WebFinger configured, a server advertising PKCE must identify both OAuth endpoints and the S256 challenge method. |

The PKCE checks cover discovery metadata. The suite uses pre-issued tokens for
storage tests, so interactive consent and authorization-code exchange are outside its scope.

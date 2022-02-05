# REST API test suite for remoteStorage servers

This test suite can be used to verify the compatibility of any server on the
Web with the REST API part of the [remoteStorage
spec](http://tools.ietf.org/html/draft-dejong-remotestorage-04) (version 03 up
to 05; valid for later versions but missing specs for some newer features).

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

# REST API test suite for remoteStorage servers

*WORK IN PROGRESS*

This test suite can be used to verify the compatibility of any server on the
Web with the REST API part of the [remoteStorage
spec](http://tools.ietf.org/html/draft-dejong-remotestorage-04) (version -04).

## Usage

You need `ruby` and `bundler` installed on your OS.

- `bundle install`
- Copy `config.yml.example` to `config.yml` and edit it.
- `rake test`

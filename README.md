# REST API test suite for remoteStorage servers

This test suite can be used to verify the compatibility of any server on the
Web with the REST API part of the [remoteStorage
spec](http://tools.ietf.org/html/draft-dejong-remotestorage-04) (version -03 up
to -05).

## Usage

You need `ruby 2.6` or `2.7` and `bundler` installed on your OS.
You need a remoteStorage test account with no data in it, 
and three tokens for that account - one with read/write access to a category
(such as `api-test`), one with read-only access to that category, and
one with read/write access to all categories.
(The [`example`](https://github.com/remotestorage/armadietto/tree/master/example) app in the Armedietto repository can help you generate these.)
You also need another account on that server 
(which can have any data in it, and which won't be altered by a successful test).

- `bundle install`
- Copy `config.yml.example` to `config.yml` and set the above values in it.
- `rake test`

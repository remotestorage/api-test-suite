# REST API test suite for remoteStorage servers

*WORK IN PROGRESS*

This test suite can be used to verify the compatibility of any server on the
Web with the REST API part of the [remoteStorage
spec](http://tools.ietf.org/html/draft-dejong-remotestorage-04) (version -04).

It is written in Ruby, so in order to run it you'll need Ruby and Bundler
installed on your system. After installing the dependencies via `bundle
install`, you can run the test suite using `rake test`.

You need to set the `TEST_RS_TOKEN` environment variable to a remoteStorage
token that has read & write permissions on the user's storage.

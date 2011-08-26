var Wick = require('./wickit').Wick;
var Exceptional = require('../lib/exceptional').Exceptional;
var assert = require('assert');

Wick.it("has default API_KEY undefined", function() {
  assert.equal(undefined, Exceptional.API_KEY);
});

Wick.it("has default protocol version set", function() {
  assert.equal(6, Exceptional.PROTOCOL_VERSION);
});


Wick.it("has default module version set", function() {
  assert.equal(1.0, Exceptional.VERSION);
});

Wick.it("has default host set", function() {
  assert.equal('api.getexceptional.com', Exceptional.Host);
});

Wick.it("has default port set", function() {
  assert.equal(80, Exceptional.Port);
});

Wick.it('test set API key', function() {
  assert.equal(Exceptional.API_KEY, undefined);
  Exceptional.API_KEY = "test-api-key";
  assert.equal(Exceptional.API_KEY, "test-api-key");
});

Wick.it('Exceptional.handle requires API_KEY to be set', function() {
  Exceptional.API_KEY = undefined;
  assert.throws(function() {
    Exceptional.handle("error");
  }, "API_KEY must be set");
});

Wick.it('creates error JSON document with exception details', function() {
  Exceptional.API_KEY = 'test-api-key';
  try {
    throw new Error("Big Problem");
  } catch(error) {
    var doc = Exceptional.error_json(error);
    var json = JSON.parse(doc);

    assert.equal("Big Problem", json.exception.message);
    assert.equal("node", json.exception.exception_class);
    assert.equal(11, json.exception.backtrace.length);
    assert.ok(json.exception.occurred_at !== undefined);
  }
});

Wick.it('creates error JSON document with client details', function() {
  Exceptional.API_KEY = 'test-api-key';
  try {
    throw new Error("Big Problem");
  } catch(error) {
    var doc = Exceptional.error_json(error);
    var json = JSON.parse(doc);

    assert.equal("Exceptional for node.js", json.client.name);
    assert.equal(1.0, json.client.version);
    assert.equal(6, json.client.protocol_version);
  }
});

Wick.it('creates error JSON document with application environment set', function() {
  Exceptional.API_KEY = 'test-api-key';
  try {
    throw new Error("Big Problem");
  } catch(error) {
    var doc = Exceptional.error_json(error);
    var json = JSON.parse(doc);

    assert.equal("node-javascript", json.application_environment.language);
    assert.ok(json.application_environment.application_root_directory !== undefined);
    assert.ok(json.application_environment.framework !== undefined);
    assert.ok(json.application_environment.env !== undefined);
  }
});


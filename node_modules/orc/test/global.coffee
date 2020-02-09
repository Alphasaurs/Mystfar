# Chai is an assertion library
chai = require 'chai'
# Sinon is a mocking library
global.sinon = require 'sinon'
# Sinon-chai is chai assertions for mocking
chai.use require 'sinon-chai'
# The tests in this library favor the expect syntax
global.expect = chai.expect

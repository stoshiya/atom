# These tests are excluded by default. To run them from the command line:
#
# ATOM_INTEGRATION_TESTS_ENABLED=true apm test
return unless process.env.ATOM_INTEGRATION_TESTS_ENABLED
# Integration tests require a fast machine and, for now, we cannot afford to
# run them on Travis.
return if process.env.CI

fs = require 'fs-plus'
path = require 'path'
temp = require('temp').track()
runAtom = require './helpers/start-atom'
CSON = require 'season'

describe "Starting Atom", ->
  atomHome = temp.mkdirSync('atom-home')
  [tempDirPath, otherTempDirPath] = []

  beforeEach ->
    jasmine.useRealClock()
    fs.writeFileSync(path.join(atomHome, 'config.cson'), fs.readFileSync(path.join(__dirname, 'fixtures', 'atom-home', 'config.cson')))
    fs.removeSync(path.join(atomHome, 'storage'))

    tempDirPath = temp.mkdirSync("empty-dir")
    otherTempDirPath = temp.mkdirSync("another-temp-dir")

  describe "launching with no path", ->
    it "doesn't reopen any previously opened windows if restorePreviousWindowsOnStart is disabled", ->
      runAtom [tempDirPath], {ATOM_HOME: atomHome}, (client) ->
        client
          .waitForExist("atom-workspace")
          .waitForNewWindow(->
            @startAnotherAtom([otherTempDirPath], ATOM_HOME: atomHome)
          , 5000)
          .waitForExist("atom-workspace")

      configPath = path.join(atomHome, 'config.cson')
      config = CSON.readFileSync(configPath)
      config['*'].core = {restorePreviousWindowsOnStart: false}
      CSON.writeFileSync(configPath, config)

      runAtom [], {ATOM_HOME: atomHome}, (client) ->
        windowProjectPaths = []

        client
          .waitForWindowCount(1, 10000)
          .then ({value: windowHandles}) ->
            @window(windowHandles[0])
            .waitForExist("atom-workspace")
            .treeViewRootDirectories()
            .then ({value: directories}) -> windowProjectPaths.push(directories)

            .call ->
              expect(windowProjectPaths).toEqual [
                []
              ]

  describe "opening a remote directory", ->
    it "opens the parent directory and creates an empty text editor", ->
      remoteDirectory = 'remote://server:3437/some/directory/path'
      runAtom [remoteDirectory], {ATOM_HOME: atomHome}, (client) ->
        client
          .treeViewRootDirectories()
          .then ({value}) -> expect(value).toEqual([remoteDirectory])

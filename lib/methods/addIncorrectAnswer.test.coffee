'use strict'

# Will access contents via share
import '../model.coffee'
import chai from 'chai'
import sinon from 'sinon'
import { resetDatabase } from 'meteor/xolvio:cleaner'

model = share.model

describe 'addIncorrectAnswer', ->
  clock = null

  beforeEach ->
    clock = sinon.useFakeTimers(7)

  afterEach ->
    clock.restore()

  beforeEach ->
    resetDatabase()
    
  it 'fails on non-puzzle', ->
    id = model.Nicks.insert
      name: 'Torgen'
      canon: 'torgen'
      tags: [{name: 'Answer', canon: 'answer', value: 'knock knock', touched: 1, touched_by: 'torgen'}]
    chai.assert.throws ->
      Meteor.call 'addIncorrectAnswer',
        type: 'nicks'
        target: id
        who: 'cjb'
        answer: 'foo'
    , Match.Error

  ['roundgroups', 'rounds', 'puzzles'].forEach (type) =>
    describe "on #{model.pretty_collection(type)}", ->
      it 'fails when it doesn\'t exist', ->
        chai.assert.throws ->
          Meteor.call 'newCallIn',
            type: type
            target: 'something'
            answer: 'precipitate'
            who: 'torgen'
        , Meteor.Error
      
      describe 'which exists', ->
        id = null
        beforeEach ->
          id = model.collection(type).insert
            name: 'Foo'
            canon: 'foo'
            created: 1
            created_by: 'cscott'
            touched: 2
            touched_by: 'torgen'
            solved: null
            solved_by: null
            tags: [{name: 'Status', canon: 'status', value: 'stuck', touched: 2, touched_by: 'torgen'}]
            incorrectAnswers: [{answer: 'qux', who: 'torgen', timestamp: 2, backsolve: false, provided: false}]
          model.CallIns.insert
            type: type
            target: id
            name: 'Foo'
            answer: 'flimflam'
            created: 4
            created_by: 'cjb'
          Meteor.call 'addIncorrectAnswer',
            type: type
            target: id
            who: 'cjb'
            answer: 'flimflam'

        it 'appends answer', ->
          doc = model.collection(type).findOne id
          chai.assert.lengthOf doc.incorrectAnswers, 2
          chai.assert.include doc.incorrectAnswers[1],
            answer: 'flimflam'
            who: 'cjb'
            timestamp: 7
            backsolve: false
            provided: false

        it 'doesn\'t touch', ->
          doc = model.collection(type).findOne id
          chai.assert.include doc,
            touched: 2
            touched_by: 'torgen'

        it 'oplogs', ->
          o = model.Messages.find(room_name: 'oplog/0').fetch()
          chai.assert.lengthOf o, 1
          chai.assert.include o[0],
            type: type
            id: id
            stream: 'callins'
            nick: 'cjb'
          # oplog is lowercase
          chai.assert.include o[0].body, 'flimflam', 'message'

        it 'deletes callin', ->
          chai.assert.lengthOf model.CallIns.find().fetch(), 0

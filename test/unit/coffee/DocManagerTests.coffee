SandboxedModule = require('sandboxed-module')
sinon = require('sinon')
chai = require('chai')
chai.should()
expect = chai.expect
modulePath = require('path').join __dirname, '../../../app/js/DocManager'
ObjectId = require("mongojs").ObjectId
Errors = require "../../../app/js/Errors"

describe "DocManager", ->
	beforeEach ->
		@DocManager = SandboxedModule.require modulePath, requires:
			"./MongoManager": @MongoManager = {}
			"logger-sharelatex": @logger = {log: sinon.stub()}
		@doc_id = ObjectId().toString()
		@project_id = ObjectId().toString()
		@callback = sinon.stub()
		@stubbedError = new Error("blew up")

	describe "getDoc", ->
		beforeEach ->
			@project = { name: "mock-project" }
			@doc = { _id: @doc_id, lines: ["mock-lines"] }
			@docCollectionDoc = { _id: @doc_id, lines: ["mock-lines"] }

		describe "when the doc is in the doc collection not projects collection", ->

			beforeEach ->
				@MongoManager.findDoc = sinon.stub()
				@MongoManager.findProject = sinon.stub().callsArgWith(1, null, @project)
				@DocManager.findDocInProject = sinon.stub().callsArgWith(2, null, @doc, @mongoPath)

			it "should get the doc from the doc collection when it is present there", (done)->
				@MongoManager.findDoc.callsArgWith(1, null, @docCollectionDoc)
				@DocManager.getDoc @project_id, @doc_id, (err, doc)=>
					doc.should.equal @docCollectionDoc
					done()

			it "should return the error from find doc", (done)->
				@MongoManager.findDoc.callsArgWith(1, @stubbedError)
				@DocManager.getDoc @project_id, @doc_id, (err, doc)=>
					err.should.equal @stubbedError
					done()

		describe "when the project exists and the doc is in it", ->
			beforeEach -> 
				@mongoPath = "mock.mongo.path"
				@MongoManager.findProject = sinon.stub().callsArgWith(1, null, @project)
				@MongoManager.findDoc = sinon.stub().callsArg(1)
				@DocManager.findDocInProject = sinon.stub().callsArgWith(2, null, @doc, @mongoPath)
				@DocManager.getDoc @project_id, @doc_id, @callback

			it "should get the project from the database", ->
				@MongoManager.findProject
					.calledWith(@project_id)
					.should.equal true

			it "should find the doc in the project", ->
				@DocManager.findDocInProject
					.calledWith(@project, @doc_id)
					.should.equal true

			it "should return the doc", ->
				@callback.calledWith(null, @doc, @mongoPath).should.equal true

		describe "when the project does not exist", ->
			beforeEach -> 
				@MongoManager.findProject = sinon.stub().callsArgWith(1, null, null)
				@MongoManager.findDoc = sinon.stub().callsArg(1)
				@DocManager.findDocInProject = sinon.stub()
				@DocManager.getDoc @project_id, @doc_id, @callback

			it "should not try to find the doc in the project", ->
				@DocManager.findDocInProject.called.should.equal false

			it "should return a NotFoundError", ->
				@callback
					.calledWith(new Errors.NotFoundError("No such project: #{@project_id}"))
					.should.equal true

		describe "when the doc is deleted", ->
			beforeEach -> 
				@MongoManager.findProject = sinon.stub().callsArgWith(1, null, @project)
				@DocManager.findDocInProject = sinon.stub().callsArgWith(2, null, null, null)
				@MongoManager.findDoc = sinon.stub().callsArgWith(1, null, @doc)

				@DocManager.getDoc @project_id, @doc_id, @callback

				it "should try to find the doc in the docs collection", ->
					@MongoManager.findDoc
						.calledWith(@doc_id)
						.should.equal true

				it "should return the doc", ->
					@callback
						.calledWith(null, @doc)
						.should.equal true

		

		describe "when the doc does not exist anywhere", ->
			beforeEach -> 
				@MongoManager.findProject = sinon.stub().callsArgWith(1, null, @project)
				@DocManager.findDocInProject = sinon.stub().callsArgWith(2, null, null, null)
				@MongoManager.findDoc = sinon.stub().callsArgWith(1, null, null)
				@DocManager.getDoc @project_id, @doc_id, @callback

			it "should return a NotFoundError", ->
				@callback
					.calledWith(new Errors.NotFoundError("No such doc: #{@doc_id}"))
					.should.equal true

	describe "getAllDocs", ->
		describe "when the project exists", ->
			beforeEach -> 
				@project = { name: "mock-project" }
				@docs = [{ _id: @doc_id, lines: ["mock-lines"] }]
				@mongoPath = "mock.mongo.path"
				@MongoManager.findProject = sinon.stub().callsArgWith(1, null, @project)
				@DocManager.findAllDocsInProject = sinon.stub().callsArgWith(1, null, @docs)
				@DocManager.getAllDocs @project_id, @callback

			it "should get the project from the database", ->
				@MongoManager.findProject
					.calledWith(@project_id)
					.should.equal true

			it "should find all the docs in the project", ->
				@DocManager.findAllDocsInProject
					.calledWith(@project)
					.should.equal true

			it "should return the docs", ->
				@callback.calledWith(null, @docs).should.equal true

		describe "when the project does not exist", ->
			beforeEach -> 
				@MongoManager.findProject = sinon.stub().callsArgWith(1, null, null)
				@DocManager.findAllDocsInProject = sinon.stub()
				@DocManager.getAllDocs @project_id, @callback

			it "should not try to find the doc in the project", ->
				@DocManager.findAllDocsInProject.called.should.equal false

			it "should return a NotFoundError", ->
				@callback
					.calledWith(new Errors.NotFoundError("No such project: #{@project_id}"))
					.should.equal true

	describe "deleteDoc", ->
		describe "when the doc exists", ->
			beforeEach ->
				@lines = ["mock", "doc", "lines"]
				@rev = 77
				@DocManager.getDoc = sinon.stub().callsArgWith(2, null, {lines: @lines, rev:@rev})
				@MongoManager.upsertIntoDocCollection = sinon.stub().callsArg(4)
				@MongoManager.markDocAsDeleted = sinon.stub().callsArg(1)
				@DocManager.deleteDoc @project_id, @doc_id, @callback

			it "should get the doc", ->
				@DocManager.getDoc
					.calledWith(@project_id, @doc_id)
					.should.equal true

			it "should update the doc lines", ->
				@MongoManager.upsertIntoDocCollection
					.calledWith(@project_id, @doc_id, @lines, @rev)
					.should.equal true

			it "should mark doc as deleted", ->
				@MongoManager.markDocAsDeleted
					.calledWith(@doc_id)
					.should.equal true

			it "should return the callback", ->
				@callback.called.should.equal true

		describe "when the doc does not exist", ->
			beforeEach -> 
				@DocManager.getDoc = sinon.stub().callsArgWith(2, null, null)
				@MongoManager.upsertIntoDocCollection = sinon.stub()
				@DocManager.deleteDoc @project_id, @doc_id, @callback

			it "should not try to insert a deleted doc", ->
				@MongoManager.upsertIntoDocCollection.called.should.equal false

			it "should return a NotFoundError", ->
				@callback
					.calledWith(new Errors.NotFoundError("No such doc: #{@doc_id}"))
					.should.equal true

	describe "updateDoc", ->
		beforeEach ->
			@oldDocLines = ["old", "doc", "lines"]
			@newDocLines = ["new", "doc", "lines"]
			@doc = { _id: @doc_id, lines: @oldDocLines, rev: @rev = 5 }
			@mongoPath = "mock.mongo.path"

			@MongoManager.updateDoc = sinon.stub().callsArg(3)
			@MongoManager.upsertIntoDocCollection = sinon.stub().callsArg(4)

		describe "when there is no rev", ->
			beforeEach ->

				delete @doc.rev
				@DocManager.getDoc = sinon.stub().callsArgWith(2, null, @doc, @mongoPath)
				@DocManager.updateDoc @project_id, @doc_id, @newDocLines, @callback	

			it "should set the rev to 0", ->
				@MongoManager.upsertIntoDocCollection.calledWith(@project_id, @doc_id, @newDocLines, 0).should.equal true

		describe "when the doc lines have changed", ->
			beforeEach ->
				@DocManager.getDoc = sinon.stub().callsArgWith(2, null, @doc, @mongoPath)
				@DocManager.updateDoc @project_id, @doc_id, @newDocLines, @callback

			it "should get the existing doc", ->
				@DocManager.getDoc
					.calledWith(@project_id, @doc_id)
					.should.equal true

			it "should update the doc with the new doc lines", ->
				@MongoManager.updateDoc
					.calledWith(@project_id, @mongoPath, @newDocLines)
					.should.equal true

			it "should upsert the document to the doc collection", ->
				@MongoManager.upsertIntoDocCollection
					.calledWith(@project_id, @doc_id, @newDocLines, @rev)
					.should.equal true				

			it "should log out the old and new doc lines", ->
				@logger.log
					.calledWith(
						project_id: @project_id
						doc_id: @doc_id
						oldDocLines: @oldDocLines
						newDocLines: @newDocLines
						rev: @doc.rev
						"updating doc lines"
					)
					.should.equal true

			it "should return the callback with the new rev", ->
				@callback.calledWith(null, true, @rev + 1).should.equal true

		describe "when the doc lines have not changed", ->
			beforeEach ->
				@DocManager.getDoc = sinon.stub().callsArgWith(2, null, @doc, @mongoPath)
				@DocManager.updateDoc @project_id, @doc_id, @oldDocLines.slice(), @callback

			it "should not update the doc", ->
				@MongoManager.updateDoc.called.should.equal false
				@MongoManager.upsertIntoDocCollection.called.should.equal false

			it "should return the callback with the existing rev", ->
				@callback.calledWith(null, false, @rev).should.equal true

		describe "when the doc does not exist", ->
			beforeEach ->
				@DocManager.getDoc = sinon.stub().callsArgWith(2, null, null, null)
				@DocManager.updateDoc @project_id, @doc_id, @newDocLines, @callback

			it "should not try to update the doc", ->
				@MongoManager.updateDoc.called.should.equal false
				@MongoManager.upsertIntoDocCollection.called.should.equal false

			it "should return a NotFoundError", ->
				@callback
					.calledWith(new Errors.NotFoundError("No such project/doc: #{@project_id}/#{@doc_id}"))
					.should.equal true

	describe "findDocInProject", ->
		it "should find the doc when it is in the root folder", (done) ->
			@DocManager.findDocInProject {
				rootFolder: [{
					docs: [{
						_id: ObjectId(@doc_id)
					}]
				}]
			}, @doc_id, (error, doc, mongoPath) =>
				expect(doc).to.deep.equal { _id: ObjectId(@doc_id) }
				mongoPath.should.equal "rootFolder.0.docs.0"
				done()

		it "should find the doc when it is in a sub folder", (done) ->
			@DocManager.findDocInProject {
				rootFolder: [{
					folders: [{
						docs: [{
							_id: ObjectId(@doc_id)
						}]
					}]
				}]
			}, @doc_id, (error, doc, mongoPath) =>
				expect(doc).to.deep.equal { _id: ObjectId(@doc_id) }
				mongoPath.should.equal "rootFolder.0.folders.0.docs.0"
				done()

		it "should find the doc when it there are other docs", (done) ->
			@DocManager.findDocInProject {
				rootFolder: [{
					folders: [{
						docs: [{
							_id: ObjectId()
						}]
					}, {
						docs: [{
							_id: ObjectId()
						}, {
							_id: ObjectId(@doc_id)
						}]
					}],
					docs: [{
						_id: ObjectId()
					}]
				}]
			}, @doc_id, (error, doc, mongoPath) =>
				expect(doc).to.deep.equal { _id: ObjectId(@doc_id) }
				mongoPath.should.equal "rootFolder.0.folders.1.docs.1"
				done()

		it "should return null when the doc doesn't exist", (done) ->
			@DocManager.findDocInProject {
				rootFolder: [{
					folders: [{
						docs: []
					}]
				}]
			}, @doc_id, (error, doc, mongoPath) =>
				expect(doc).to.be.null
				expect(mongoPath).to.be.null
				done()

	describe "findAllDocsInProject", ->
		it "should return all the docs", (done) ->
			@DocManager.findAllDocsInProject {
				rootFolder: [{
					docs: [
						@doc1 = { _id: ObjectId() }
					],
					folders: [{
						docs: [
							@doc2 = { _id: ObjectId() }
						]
					}, {
						docs: [
							@doc3 = { _id: ObjectId() }
							@doc4 =  { _id: ObjectId() }
						]
					}]
				}]
			}, (error, docs) =>
				expect(docs).to.deep.equal [@doc1, @doc2, @doc3, @doc4]
				done()

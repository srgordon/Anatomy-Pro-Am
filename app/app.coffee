config = require '../config'

## dependencies
DNode = require 'dnode@0.6.6'
Hash = require 'hashish@0.0.2'
_ = require('underscore@1.1.5')._
Backbone = require 'backbone@0.3.3'
resources  = require '../models/resources'
fbgraph = require 'facebook-graph@0.0.6'
# memory store class for storing it in the memory (update: replace with redis)
class MemoryStore
	constructor: () ->
		@data = {}
	create: (@model) ->
		if not model.id
			model.id = model.attributes.id = Date.now()
			@data[model.id] = model
			return model
	set: (@model) ->
		@data[model.id] = model
		return model
	get: (@model) ->
		if model and model.id
			return @data[model.id]
		else
			return _.values(@data)
	destroy: (@model) ->
		delete @data[model.id]
		return model

store = new MemoryStore

# overwrite Backbone's sync, to store it in the memory
Backbone.sync = (method, model, success, error) ->
	switch method
		when "read" then resp = store.get model
		when "create" then resp = store.create model
		when "update" then resp = store.set model
		when "delete" then resp = store.destroy model
	if resp
		success(resp)
	else
		console.log(error)


drawing = new resources.collections.Drawing
players = new resources.collections.Players

## pub/sub
subs = {}
publish = () ->
	args = arguments
	cl = args[1]
	if not _.isUndefined args[2] then args = _.without args, cl
	Hash(subs).forEach (emit, sub) ->
		if sub isnt cl
			emit.apply emit, args

## DNode RPC API
exports.createServer = (app) ->
	client = DNode (client, conn) ->
		conn.on 'end', ->
			console.log("END")
			user = fbgraph.getUserFromCookie(req.cookies, config.fbconfig.appId, config.fbconfig.appSecret)
			if user
				players.each (player) ->
					if player.playerID == user.uid
						p = players.get(player)
						console.log(p)
						players.destroy (p)
				
			
		@subscribe = (emit) ->
			subs[conn.id] = emit
			conn.on 'end', ->
				console.log 'player left'
				publish 'leave', conn.id
				client.remove
				delete subs[conn.id]
		@add = (data, options) ->
			aColl = eval options.type
			aColl.create data
			client.add data, { type: options.type }
		@remove = (data, options) ->
			aColl = eval options.type
			m = aColl.get data
			if m
				m.destroy()
				client.remove data, { type: options.type }
		@removeAll = (options) ->
			aColl = eval options.type
			aColl.each (m) ->
				m.destroy()
				client.removeAll { type: options.type }
		# dnode/coffeescript fix:
		@version = config.version
	.listen(app)
	app.get '/drawing', (req, res) ->
		drawing.fetch {
			success: (data) ->
				res.writeHead 200
				res.end JSON.stringify(data)
			error: (err) ->
				res.writeHead 204
				res.end err
		}
	app.get '/players', (req, res) ->
		players.fetch {
			success: (data) ->
				res.writeHead 200
				res.end JSON.stringify(data)
			error: (err) ->
				res.writeHead 204
				res.end err
		}

# temp fix, added callback
exports.setFbUser = (data) ->
	if data
		newUser = {
			playerID: data.id
			name: data.first_name
			avatar: "http://graph.facebook.com/" + data.id + "/picture"
		}
		players.create (newUser)
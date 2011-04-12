Hash = require 'hashish@0.0.2'

###
#	SESSION MANAGER
###

GenerateRandomKey = () ->
	#generate random key for this session
	chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXTZabcdefghiklmnopqrstuvwxyz";
	key_length = 32
	ret = ""
	for x in [0..32]
		rnum = Math.floor(Math.random() * chars.length)
		ret += chars.substring(rnum,rnum+1)

	return ret

class Session
	constructor: (@facebook_id, @fbUser) ->
		@random_key = GenerateRandomKey()
		@connection = ''
		@client = ''

class SessionManager
	constructor: (@id, @player) ->
		@sessions_for_connection = {}
		@sessions_for_facebook_id = {}
		@sessions_for_random_key = {}
	
	#call this when the user has done the facebook authentication
	#this returns a random session key that should be used to authenticate the dnode connection
	createSession: (player) =>
		session = new Session(player.id, player)
		session_key = session.random_key
		@sessions_for_facebook_id[player.id] = session
		@sessions_for_random_key[session_key] = session		
		return session_key
	
	#this should be called when the client sends an authenticate message over dnone. 
	#this must be done before anything else over dnone
	sessionConnected: (random_key, conn, client, emit) ->
		console.log("Session connection started! Connection ID = "+conn.id)
		if @sessions_for_random_key[random_key]
			session = @sessions_for_random_key[random_key]
			@sessions_for_connection[conn.id] = session
			session.connection = conn
			session.client = client
			session.emit = emit
			
			emit.apply emit, ['myUID', session.facebook_id]
			
			# temp notification to tell all users for the global session that a player came online
			Hash(@sessions_for_connection).forEach (player) ->
				player.emit.apply player.emit, ['FriendCameOnline', player.facebook_id]
			
			# notify this player's friends of disconnection e.g., something like
			#for friend in friends_for_player[player]
			#	@sessions_for_facebook_id[friend_id].client.friendSignedOn @session.person 
		else
			console.log("Session connected started with invalid random_id!!!!")
			
	sessionDisconnected: (conn) ->
		console.log("Session ended! Disconnected ID = "+conn.id)
		
		# temp notification to tell all users for the global session that a player went offline
		Hash(@sessions_for_connection).forEach (player) ->
			player.emit.apply player.emit, ['FriendWentOffline', player.facebook_id]
			
		
		#player = @playerForConnection conn.id
		# notify this player's friends of disconnection
		
		delete @sessions_for_facebook_id[@sessions_for_connection[conn.id].facebook_id]
		delete @sessions_for_connection[conn.id]
	
	publish: () ->
		args = arguments
		Hash(@sessions_for_connection).forEach (player) ->
			player.emit.apply player.emit, args
	
	playerForConnection: (conn) ->
		@sessions_for_connection[conn.id].player

###
#	CONTOURING ACTIVITY
###
class ContouringActivity
	constructor: () ->
		@id = GenerateRandomKey()
		@activityData = new ContouringActivityData(@id)
		@players = {}
	addPlayer: (player) ->
		@players[player.id] = player
	createPoint: (player_id, point) ->
		@activityData.newPoint player_id, point
	deletePoint: (player_id, point) ->
		@activityData.removePoint player_id, point

###
#	CONTOURING ACTIVTY DATA
###
class ContouringActivityData
	constructor: (@id) ->
		@data_for_player = []
	newPoint: (player_id, point) ->
		if not @data_for_player[player_id]
			@data_for_player[player_id] = []
		@data_for_player[player_id][point] = point
	removePoint: (player_id, point) ->
		delete @data_for_player[player_id][point]

###
#	MEMORY STORE
###

# memory store class for storing it in the memory (update: replace with redis)
class MemoryStore
	constructor: () ->
		@data = {}
	create: (model) ->
		if not model.id
			model.id = model.attributes.id = @guid
			@data[model.id] = model
			return model
	update: (model) ->
		@data[model.id] = model
		return model
	find: (model) ->
		if model and model.id
			return @data[model.id]
	findAll: () ->
		return _.values(@data)
	destroy: (model) ->
		delete @data[model.id]
		return model
	S4: () ->
		return (((1+Math.random())*0x10000)|0).toString(16).substring(1)
	guid: () ->
		return (@S4()+@S4()+"-"+@S4()+"-"+@S4()+"-"+@S4()+"-"+@S4()+@S4()+@S4())		

exports.SessionManager = SessionManager
exports.MemoryStore = MemoryStore
exports.ContouringActivity = ContouringActivity
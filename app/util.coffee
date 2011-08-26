config = require '../config'

Hash = require 'hashish@0.0.2'
_ = require('underscore@1.1.5')._
redis = require 'redis@0.6.0'

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
		@currentActivity = 0
		
	#call this when the user has done the facebook authentication
	#this returns a random session key that should be used to authenticate the dnode connection
	createSession: (player) =>
		session = new Session(player.id, player)
		session_key = session.random_key
		@sessions_for_facebook_id[player.id] = session
		player.player_color = '55AA55'
		@sessions_for_random_key[session_key] = session	
		@currentActivity = 0	
		return session_key
	
	#this should be called when the client sends an authenticate message over dnone. 
	#this must be done before anything else over dnone
	sessionConnected: (random_key, conn, client, emit) ->
		if @sessions_for_random_key[random_key]
			session = @sessions_for_random_key[random_key]
			@sessions_for_connection[conn.id] = session
			session.connection = conn
			session.client = client
			session.emit = emit
			
			return session
		else
			console.log("Session connected started with invalid random_id!!!!")
			
	setActivity: (playerInfo, activityID) ->
		@sessions_for_facebook_id[playerInfo.id].currentActivity = activityID
		
	sessionDisconnected: (conn) ->
		console.log conn
		#ActivityManager.current[@sessions_for_connection[conn.id].facebook_id].UnsetColor(@sessions_for_connection[conn.id].facebook_id)
		
		session_conn = @sessions_for_connection[conn.id]
		
		delete @sessions_for_facebook_id[@sessions_for_connection[conn.id].facebook_id]
		delete @sessions_for_connection[conn.id]
		
		return session_conn
	
	# publishToAll is to send a message to all connected users
	publishToAll: () ->
		args = arguments
		Hash(@sessions_for_connection).forEach (player) ->
		  player.emit.apply player.emit, args
	
	# publishToActivity is to send a message to all conected users within a activity that is defined as the first argument
	publishToActivity: () ->
	  args = arguments
	  Hash(@sessions_for_connection).forEach (connection) ->
	    Hash(args[0]).forEach (player) ->
	      if player is connection.facebook_id
	        connection.emit.apply connection.emit, _.without(args, args[0])
	
	sendJoinRequest: () ->
		args = arguments
		Hash(@sessions_for_connection).forEach (player) ->
			if player.facebook_id is args[3]
				player.emit.apply player.emit, args
	
	playerForConnection: (conn) ->
		@sessions_for_connection[conn.id].player

###
#	CONTOURING ACTIVITY
###
class ActivityManager
	constructor: () ->
		@current = []
	newActivity: (case_number, thisPlayer) ->
		activity = new ContouringActivity
		activity.addPlayer thisPlayer
		activity.setCaseID case_number
		@current[activity.id] = activity	
		return activity.id

		
class ContouringActivity
	getColor : (userID, cb) ->
		returnedcolor = 'asdf'
		assigned = false
		_.each @colors, (color) ->
			if assigned is false
				if color.user is undefined 
					returnedcolor = color.hex
					color.user = userID
					assigned = true
				else
					returnedcolor = 'FFFFFF'
		cb returnedcolor
	unsetColor : (userID) ->
		_.each @colors, (color) ->
			if color.user is userID[0]
				color.user = undefined
				
	constructor: () ->
		@id = GenerateRandomKey()
		@activityData = new ContouringActivityData(@id)
		@players = {}
		@colors = [ 
			{ hex: 'FFCC00', user: undefined },
			{ hex: 'FF004E', user: undefined },
			{ hex: '009CFF', user: undefined },
			{ hex: 'FF6C00', user: undefined },
			{ hex: 'A900A3', user: undefined },
			{ hex: '20E500', user: undefined },
			{ hex: 'FFFF00', user: undefined },
			{ hex: 'FF00FF', user: undefined },
			{ hex: '00FF00', user: undefined },
			{ hex: '00FFFF', user: undefined },
			{ hex: '0000FF', user: undefined } 
		]
	getID: () ->
		return @id
	getCaseID: () ->
		return @caseID
	setCaseID: (case_id) ->
		@caseID = case_id
	addPlayer: (player) ->
		@players[player.id] = player
	removePlayer: (player) ->
		@players[player] = null
	getPlayers: () ->
		playerIDs = []
		Hash(@players).forEach (player) ->
			playerIDs.push player.id
		return playerIDs
	createPoint: (player_id, point) ->
		@activityData.newPoint player_id, point
	deletePoint: (player_id, point, callback) ->
		return @activityData.removePoint player_id, point, callback
	clearCanvas: (player_id, layer, callback) ->
		return @activityData.clearCanvas player_id, layer, callback
	getPointsForPlayer: (layer, player_id, callback) ->
		return @activityData.getPointsForPlayer layer, player_id, callback
	addChatMessage: (player_id, message) ->
	    @activityData.newChat player_id, message    
	getChatHistoryForActivity: (callback) ->
	    return @activityData.getChatHistoryForActivity callback
	getGoalPointsForCase: (callback) ->
	    return @activityData.getGoalPointsForCase callback
	setGoalPointsForCase: (goalPoints) ->
	    @activityData.setGoalPointsForCase goalPoints
	getScoreForCase: (player_id, width, height, callback) ->
		return @activityData.getScoreForCase player_id, width, height, callback
	
	
	playerDone: (player, tumorHit, healthyHit, callback) ->
		@players[player.id].isDone = true
		@players[player.id].tumorHit = tumorHit
		@players[player.id].healthyHit = healthyHit
		result = true;
		_.each @players, (player) ->
			if player.isDone != true
				result = false;
		callback result
	getScores: (player, callback) ->
		returned = {}
		returned['result'] = false
		returned['scores'] = {}
		@players[player.id].requestsScore = true
		scoreResult = true;
		doneResult = true
		_.each @players, (player) ->
			returned['scores'][player.id] = {}
			returned['scores'][player.id]['id'] = player.id
			returned['scores'][player.id]['tumorHit'] = player.tumorHit
			returned['scores'][player.id]['healthyHit'] = player.healthyHit
			if player.requestsScore != true
				scoreResult = false;
		_.each @players, (player) ->
			if player.isDone != true
				doneResult = false;
		returned.result = doneResult && scoreResult
		callback returned
	playerNotDone: (player) ->
		@players[player.id].isDone = false
		@players[player.id].scoreResult = false
		
###
#	CONTOURING ACTIVTY DATA
###
class ContouringActivityData
	constructor: (@id) ->
		@redisClient = redis.createClient config.redis.port, config.redis.server
		@redisClient.select config.redis.db
	newPoint: (player_id, point) ->
		client = @redisClient
		thisID = @id
		client.sismember 'activity:'+thisID+':layer:'+point.layer+':player:'+player_id+':points', JSON.stringify({point}), (err, ismember) ->
			if err then console.log 'SISMEMBER error: ', err
			if ismember is 0
				client.sadd 'activity:'+thisID+':layer:'+point.layer+':player:'+player_id+':points', JSON.stringify({point}), (err, added) ->
					if err then console.log 'SADD error: ', err
	removePoint: (player_id, point) ->
		@redisClient.srem 'activity:'+@id+':layer:'+point.layer+':player:'+player_id+':points', JSON.stringify({point}), (err) ->
			if err then console.log 'SISMEMBER error: ', err
	clearCanvas: (player_id, layer, callback) ->
		@redisClient.del 'activity:'+@id+':layer:'+layer+':player:'+player_id+':points', (err, data) ->
			if err then console.log 'DEL error: ', err
	getPointsForPlayer: (layer, player, callback) ->
		@redisClient.smembers 'activity:'+@id+':layer:'+layer+':player:'+player+':points', (err, points) ->
			if err then console.log 'SMEMBERS error: ', err
			data = []
			_.each points, (point) ->
				data.push JSON.parse point
			callback data
	newChat: (player_id, message) ->
	    @redisClient.sadd 'activity:'+@id+':chat', JSON.stringify({player: player_id, message: message, timestamp: new Date().getTime()}), (err, added) ->
	        if err then console.log 'SADD error: ', err
	getChatHistoryForActivity: (callback) ->
        @redisClient.smembers 'activity:'+@id+':chat', (err, chats) ->
            if err then console.log 'SMEMBERS error: ', err
            data = []
            _.each chats, (chat) ->
                data.push JSON.parse chat
            callback data
	getGoalPointsForCase: (callback) ->
        @redisClient.smembers 'Case:'+@caseID+':GoalPoints', (err, goalPoints) ->
            if err then console.log 'SMEMBERS error: ', err
            data = []
            _.each goalPoints, (goalPoint) ->
                data.push JSON.parse goalPoint
            callback data
	setGoalPointsForCase: (goalPoints) ->
	    @redisClient.sadd 'Case:'+@caseID+':GoalPoints', JSON.stringify({goalPoints: goalPoints}), (err, added) ->
	        if err then console.log 'SADD error: ', err
	getScoreForCase: (player_id, width, height, callback) ->
		self = @
		score = []
		score[0] = 0 #Hit
		score[1] = 0 #Missed
		@redisClient.smembers 'Case:'+@caseID+':GoalPoints', (err, goalPoints) ->
			if err then console.log 'SMEMBERS error: ', err
			data = []
			layerIndex = 0
			console.log("makes it here")
			_.each goalPoints, (goalPoint) ->
				currentLayerGoalPoints = JSON.parse goalPoint
				layerPointData = []
				#get layer data for player

				self.redisClient.smembers 'activity:'+self.id+':layer:'+layerIndex+':player:'+player_id+':points', (err, points) ->
					if err then console.log 'SMEMBERS error: ', err	
					_.each points, (point) ->
						layerPointData.push JSON.parse point
					console.log("now this place")
					`

					console.log("here to here");
							//arrayify data
							//console.log(points);
							//console.log(currentLayerGoalPoints);
							var goalPointsXY = currentLayerGoalPoints.goalPoints;
							var mainPointArr = new Array(width*height);
							for(var y = 0; y < height; y++)
								for(var x = 0; x < width; x++){
									mainPointArr[y*width+x] = 0;
								}
							for(key in layerPointData){
								mainPointArr[layerPointData[key].point.x+(layerPointData[key].point.y*width)] = 1;
							}		

							console.log(mainPointArr.length);
							//blobify data
							var pixelStack = [[0, 0]];
							while(pixelStack.length)
							{
								var newPos, x, y, pixelPos, reachLeft, reachRight;
								newPos = pixelStack.pop();
								x = newPos[0];
								y = newPos[1];

								pixelPos = (y*width + x);
								while(y-- >= 0 && (mainPointArr[pixelPos]==0)){
									pixelPos -= width * 4;
								}
								pixelPos += width * 4;
								++y;
								reachLeft = false;
								reachRight = false;
								while(y++ < height-1 && (mainPointArr[pixelPos]==0))
								{
									mainPointArr[pixelPos]=2;
									if(x > 0)
									{
										if(mainPointArr[(pixelPos - 1)]==0)
										{
											if(!reachLeft){
												pixelStack.push([x - 1, y]);
												reachLeft = true;
											}
										}
										else if(reachLeft)
										{
											reachLeft = false;
										}
									}

									if(x < width-1)
									{
										if(mainPointArr[(pixelPos + 1)]==0)
										{
											if(!reachRight)
											{
												pixelStack.push([x + 1, y]);
												reachRight = true;
											}
										}
										else if(reachRight)
										{
											reachRight = false;
										}
									}
								pixelPos += width;
								}
							}
							//invert

							for(var y = 0; y < height; y++){
								for(var x = 0; x < width; x++){
									if(mainPointArr[((y*(width)) + (x))] == 2){
										mainPointArr[((y*(width)) + (x))] = 0;
									}else{
										mainPointArr[((y*(width)) + (x))] = 1;
									}
								}
							}

							//compare against goalData
							var healthyHit = 0;
							var healthyMissed = 0;
							var offsetLeft = 0;
							var goalArrX = new Array();
							var goalArrY = new Array();
							var healthyArrX = new Array();
							var healthyArrY = new Array();	

						//	console.log("goalpoints");
						//	console.log(goalPointsXY);


							for(var c = 0; c<(goalPointsXY.length/2); c++){
								goalArrX[c]=goalPointsXY[c*2+0] + offsetLeft;
								goalArrY[c]=goalPointsXY[c*2+1];
							}

								console.log("goalArrX length");
								console.log(goalArrX.length);

							for(var c = 0; c < goalArrX.length; c++){
								if((mainPointArr[((goalArrY[c]*(width)) + (goalArrX[c]))]==1)){
									 score[0]++;
									}else{
										score[1]++;
									}
								}
							console.log("score TIME");
							console.log(score);
					/*
						for(var c = 0; c < healthyArrX.length; c++){
							if((newImageData.data[((healthyArrY[c]*(newImageData.width*4)) + (healthyArrX[c]*4)) + 3]) >= 100)
								healthyHit++;
							else
								healthyMissed++;
						}
					*/






					`
					console.log("made it out")
					callback score
				layerIndex = layerIndex + 1


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
exports.ActivityManager = ActivityManager
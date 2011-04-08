$(function(exports){
	var Backbone = require('backbone@0.3.3'),
		_ = require('underscore')._,
		resources = require('./models/resources'),
		drawing = new resources.collections.Drawing,
		players = new resources.collections.Players,
		view = {};

	window.Player = Backbone.View.extend({
		tagName: 'li',
		initialize: function() {
			this.template = _.template($('#player-template').html());
			_.bindAll(this, 'render');
			this.model.bind('change', this.render);
			this.model.view = this;
		},
		render: function() {
			$(this.el).html(this.template(this.model.toJSON()));
			this.setContent();
			return this;
		},
		setContent: function() {
			console.log(this.model.get('avatar'));
			//console.log(this.$('fb_player_img').attr('style'));
			this.$('.fb_player_img').attr('style', 'background: url(\'' + this.model.get('avatar')  + '\');');
			this.$('span').text(this.model.get('name'));
		},
		remove: function() {
			$(this.el).remove();
		}
	});
	/*
	window.Point = Backbone.View.extend({
		initialize: function() {
			_.bindAll(this, 'render');
			this.model.view = this;
			this.canvas = $('.game').dom[0];
			this.ctx = this.canvas.getContext("2d");
			this.ctx.fillStyle = "rgb(200,0,0)";
			this.render();
		},
		render: function() {
			this.ctx.beginPath();
			this.ctx.arc(this.model.get('x'), this.model.get('y'), 10, 0, Math.PI*2, true); 
			this.ctx.closePath();
			this.ctx.fill();
			return this;
		}
	});
	*/
	window.CaseView = Backbone.View.extend({
		el: $('#game'),
		events: {
			'click .light_grey_gradient_text': 'selectCase'
		},
		initialize: function() {
			_.bindAll(this, 'render');
			this.render();
		},
		render: function() {
			if (view.cases) {
				console.log('cashed version');
				this.el.html('');
				this.el.html(view.cases);
			} else {
				$.get('/renders/cases.html', function(t){
					this.el.html('');
					view.cases = t;
					this.el.html(view.cases);
				}.bind(this));
			}
			
		},
		selectCase: function(e) {
			//console.log($(e.currentTarget));
			e.preventDefault();
			new ComputerView;
		}
	});
	
	window.ComputerView = Backbone.View.extend({
		el: $('#game'),
		events: {
			'click .light_grey_gradient_text': 'goBack'
		},
		initialize: function() {
			_.bindAll(this, 'addOne', 'addAll', 'render');
			players.bind('add', this.addOne);
			players.bind('refresh', this.addAll);
			
			this.render();
		},
		render: function() {
			if (view.computer) {
				this.el.html('');
				this.el.html(view.computer);
				this.setupView();
			} else {
				$.get('/renders/computer.html', function(t){
					this.el.html('');
					view.computer = t;
					this.el.html(view.computer);
					this.setupView();
				}.bind(this));
			}
		},
		setupView: function() {
			players.fetch({success: function(data) { console.log(data); } });
			DNode({
				add: function(data, options) {
					var aColl = eval(options.type);
					 if (!aColl.get(data.id)) aColl.add(data);
				}
		// 		setPlayerID: function (id){
		//			playerID = id;
		//		}
			}).connect();
		},
		addAll: function() {
			players.each(this.addOne);
		},
		addOne: function(player) {
			console.log("STUFF")
			console.log(player)
			var view = new Player({model: player});
			this.$('#fb_friends_container').append(view.render().el);
		},
		goBack: function(e) {
			e.preventDefault();
			new CaseView;
		}
	});
	
	window.AppView = Backbone.View.extend({
		el: $('#game'),
		events: {
			'click .light_grey_gradient_text': 'startGame'
		},
		initialize: function() {
			_.bindAll(this, 'render');
			this.render();
		},
		render: function() {
			$.get('/renders/splash.html', function(t){
				this.el.html(t);
			}.bind(this));
		},
		startGame: function(e) {
			e.preventDefault();
			new CaseView;
		}
		
			/*
			this.canvas = $('.game').dom[0];
			ctx = this.canvas.getContext("2d");
			
			_.bindAll(this, 'drawPoint', 'drawnPoints');
			var self = this;
			drawing.bind('add', this.drawPoint);
			drawing.bind('refresh', function(data) {
				data.each(function(model){
					if(self.drawnPoints[model.id]) {
						self.drawnPoints[model.id].model.set(model.attributes);
					} else {
						self.drawPoint(model);
					}
				});
			});
			
			// old fashion request to get the current state
			drawing.fetch({success: function(data) { } });
			
			DNode({
				// clientside RPC, these methods are called by the server
				add: function(data, options) {
					var aColl = eval(options.type);
					if (!aColl.get(data.id)) aColl.add(data);
				}
			}).connect(function(remote){
				var em = require('events').EventEmitter.prototype;
				remote.subscribe(function () {
					em.emit.apply(em, arguments);
				});
				// listen to events from the collection
				drawing.bind('drawing:add', function(data){
					// do a RPC (its either add or remove, type is the collection name)
					remote.add(data, {
						type: 'drawing'
					});
				});
			});
		},
		drawnPoints: {},
		drawPoint: function(model) {
			var point = new Point({model: model});
			this.drawnPoints[model.id] = point;
		},
		setNewPoint: function(event) {
			// trigger event (via collection)
			drawing.trigger('drawing:add', {x: event.clientX-this.canvas.offsetLeft, y: event.clientY-this.canvas.offsetTop});
			event.preventDefault();
		},
		clearPoints: function(event) {
			drawing.trigger('drawing:removeAll', {x: event.clientX-this.canvas.offsetLeft, y: event.clientY-this.canvas.offsetTop});
			event.preventDefault();
		}*/
	});
	
	// todo: get all views (renders) first during the splash screen.
	window.App = new AppView;
});

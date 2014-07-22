.factory 'PostFormFactory', ($window) ->
	/*
		Transform obj for POST body.
	*/
	transform: (obj) -> 
		encode = $window.encodeURIComponent
		joinValue = (value, name) ->
			| value? => switch
				| name? => "#{encode name}=#{encode value}"
				| _     => "#{encode value}"
			| _         => null

		resolve = (obj, parent = null) ->
			eachValue = (f) ->
				for index, value of obj
					resolve value, if parent
						then "#{parent}#{f(index)}"
						else "#{index}"
			switch
			| obj instanceof Array  => eachValue (i) -> "[#i]"
			| obj instanceof Object => eachValue (i) -> ".#i"
			| _                     => [ joinValue(obj, parent) ]
		(_.compact _.flatten resolve obj).join '&'

.factory 'PhotoFactory', ->
	/*
		Select a photo from storage.
		onSuccess(image-uri)
		onFailure(error-message)
	*/
	select: (onSuccess, onFailure = (msg) !-> alert msg) !->
		navigator.camera.getPicture onSuccess, onFailure,
			correctOrientation: true
			encodingType: Camera.EncodingType.JPEG
			sourceType: Camera.PictureSourceType.PHOTOLIBRARY
			destinationType: Camera.DestinationType.FILE_URI

.factory 'ReportFactory', ($log, $interval, $ionicPopup, TicketFactory, ServerFactory, DistributionFactory) ->
	limit = 30
	store =
		reports: []
		hasMore: false

	loadServer = (last-id = null, taker) !->
		TicketFactory.get (ticket) ->
			ServerFactory.load-reports ticket, limit, last-id
		, taker
		, (error) !->
			$ionicPopup.alert do
				title: "Failed to load from server"
				template: error.msg
			.then (res) !-> taker null

	reload = (success) !->
		loadServer null, (more) !->
			store.reports = more
			store.hasMore = limit <= more.length
			success! if success

	$interval !->
		reload!
	, 6 * 60 * 60 * 1000

	cachedList: ->
		store.reports
	hasMore: ->
		store.hasMore
	/*
		Get index of list by report id
	*/
	getIndex: (id) ->
		_.find-index (.id == id), store.reports
	/*
		Get a report by index of cached list
	*/
	getReport: (index) ->
		$log.debug "Getting report[#{index}]"
		store.reports[index]
	/*
		Clear all cache
	*/
	clear: !->
		store.reports = []
		store.hasMore = true
		$log.debug "Reports cleared."
	/*
		Refresh cache
	*/
	refresh: reload
	/*
		Load reports from server
	*/
	load: (success) !->
		last-id = store.reports[store.reports.length - 1]?.id ? null
		loadServer last-id, (more) !->
			store.reports = store.reports ++ more
			store.hasMore = limit <= more.length
			$log.info "Loaded #{more.length} reports, Set hasMore = #{store.hasMore}"
			success! if success
	/*
		Add report
	*/
	add: (report) !->
		store.reports = angular.copy([report] ++ store.reports)
		DistributionFactory.report.add report
	/*
		Remove report specified by index
	*/
	remove: (index, success) !->
		removing-id = store.reports[index].id
		TicketFactory.get (ticket) ->
			ServerFactory.remove-report ticket, removing-id
		, !->
			$log.info "Deleted report: #{removing-id}"
			DistributionFactory.report.remove removing-id
			store.reports = angular.copy((_.take index, store.reports) ++ (_.drop index + 1, store.reports))
			success!
		, (error) !->
			$ionicPopup.alert do
				title: "Failed to remove from server"
				template: error.msg
	/*
		Update report
	*/
	update: (report, success) ->
		TicketFactory.get (ticket) ->
			ServerFactory.update-report ticket, report
		, !->
			$log.info "Updated report: #{report.id}"
			DistributionFactory.report.update report
			success!
		, (error) !->
			$ionicPopup.alert do
				title: "Failed to update to server"
				template: error.msg

.factory 'UnitFactory', ($log, TicketFactory, ServerFactory) ->
	inchToCm = 2.54
	pondToKg = 0.4536
	default-units =
		length: 'cm'
		weight: 'kg'

	store =
		unit: null

	save-current = (units) !->
		store.unit = angular.copy units
		TicketFactory.get (ticket) ->
			ServerFactory.change-units ticket, units
		, !-> $log.debug "Success to change units"
		, (error) !-> $log.debug "Failed to change units"
	load-local = -> store.unit ? default-units
	load-server = (taker) !->
		TicketFactory.get (ticket) ->
			ServerFactory.load-units ticket
		, (units) !->
			$log.debug "Loaded account units: #{units}"
			store.unit = angular.copy units
			taker units
		, (error) !->
			$log.error "Failed to load account units: #{error}"
			taker(angular.copy default-units)
	load-current = (taker) !->
		if store.unit
		then taker(angular.copy that)
		else load-server taker
	init = !->
		if ! store.unit
		then load-server (units) !->
			$log.debug "Refresh units: #{angular.toJson units}"

	units: -> angular.copy do
		length: ['cm', 'inch']
		weight: ['kg', 'pond']
	load: load-current
	save: save-current
	length: (src) ->
		init!
		dst-unit = load-local!.length
		convert = -> switch src.unit
		| dst-unit => src.value
		| 'inch'   => src.value * inchToCm
		| 'cm'     => src.value / inchToCm
		{
			value: convert!
			unit: dstUnit
		}
	weight: (src) ->
		init!
		dst-unit = load-local!.weight
		convert = -> switch src.unit
		| dst-unit => src.value
		| 'pond'   => src.value * pondToKg
		| 'kg'     => src.value / pondToKg
		{
			value: convert!
			unit: dstUnit
		}

.factory 'DistributionFactory', ($log, $interval, $ionicPopup, TicketFactory, ServerFactory) ->
	store =
		/*
		List of
			report-id: String (only if mine)
			name: String
			count: Int
			date: Date
			geoinfo:
				latitude: Double
				longitude: Double
		*/
		catches:
			mine: null
			others: null
		/*
		List of
			name: String
			count: Int
		*/
		names: null

	refresh-mine = (success) !->
		$log.debug "Refreshing distributions of mine ..."
		suc = !->
			success! if success
		TicketFactory.get (ticket) ->
			ServerFactory.catches-mine ticket
		, (list) !->
			store.catches.mine = list
			suc!
		, (error) !->
			$ionicPopup.alert do
				title: "Error"
				template: "Failed to load catches list"
			.then !->
				suc!
	refresh-others = (success) !->
		$log.debug "Refreshing distributions of others ..."
		suc = !->
			success! if success
		TicketFactory.get (ticket) ->
			ServerFactory.catches-others ticket
		, (list) !->
			store.catches.others = list
			suc!
		, (error) !->
			$ionicPopup.alert do
				title: "Error"
				template: "Failed to load catches list"
			.then !->
				suc!
	refresh-names = (success) !->
		$log.debug "Refreshing distributions of names ..."
		suc = !->
			success! if success
		TicketFactory.get (ticket) ->
			ServerFactory.catches-names ticket
		, (list) !->
			store.names = list
			suc!
		, (error) !->
			suc!

	$interval !->
		refresh-mine!
		refresh-others!
		refresh-names!
	, 6 * 60 * 60 * 1000

	remove-mine = (report-id) !->
		$log.debug "Removing distribution of report id:#{report-id}"
		if store.catches.mine then
			store.catches.mine = _.filter (.report-id != report-id), that
	add-mine = (report) !->
		list = _.map (fish) ->
			report-id: report.id
			name: fish.name
			count: fish.count
			date: report.dateAt
			geoinfo: report.location.geoinfo
		, report.fishes
		if store.catches.mine then
			store.catches.mine = that ++ list
			$log.debug "Added distribution of catches:#{angular.toJson list}"

	startsWith = (word, pre) ->
		word.toUpperCase!.indexOf(pre) == 0

	report:
		add: add-mine
		remove: remove-mine
		update: (report) !->
			remove-mine report.id
			add-mine report
	name-suggestion: (pre-name, success) !->
		check-or = (fail) !->
			if store.names then
				src = that
				pre = pre-name?.toUpperCase!
				list = if pre
					then _.filter ((a) -> startsWith(a, pre)), src
					else []
				success _.map (.name), _.reverse _.sort-by (.count), list
			else fail!
		check-or !->
			refresh-names !->
				check-or !->
					success []
	mine: (pre-name, success) !->
		check-or = (fail) !->
			if store.catches.mine then
				src = that
				pre = pre-name?.toUpperCase!
				list = if pre
					then _.filter ((a) -> startsWith(a.name, pre)), src
					else src
				success _.reverse _.sort-by (.count), list
			else fail!
		check-or !->
			refresh-mine !->
				check-or !->
					success []
	others: (pre-name, success) !->
		check-or = (fail) !->
			if store.catches.others then
				src = that
				pre = pre-name?.toUpperCase!
				list = if pre
					then _.filter ((a) -> startsWith(a.name, pre)), src
					else src
				success _.reverse _.sort-by (.count), list
			else fail!
		check-or !->
			refresh-others !->
				check-or !->
					success []

.factory 'ServerFactory', ($log, $http, $ionicPopup, serverURL) ->
	url = (path) -> "#{serverURL}/#{path}"
	retryable = (retry, config, res-taker, error-taker) !->
		$http config
		.success (data, status, headers, config) !-> res-taker data
		.error (data, status, headers, config) !->
			$log.error "Error on request:#{angular.toJson config} => (#{status})#{data}"
			error = http-error.gen status, data
			if error.type == http-error.types.error && retry > 0
			then retryable retry - 1, config, res-taker, error-taker
			else error-taker error
	http = (method, path, data = null, content-type = "text/json") -> (res-taker, error-taker, retry = 3) !->
		retryable retry,
			method: method
			url: url(path)
			data: data
			headers:
				if data
				then 'Content-Type': content-type
				else {}
		, res-taker, error-taker

	http-error =
		types:
			fatal: 'Fatal'
			error: 'Error'
			expired: 'Expired'
		gen: (status, data) -> switch status
		| 400 =>
			if data.indexOf('Expired') > -1 then
				type: @types.expired
				msg: data
			else
				type: @types.Error
				msg: data
		| 404 =>
			type: @types.fatal
			msg: "Not Found"
		| 501 =>
			type: @types.fatal
			msg: "Not Implemented: #{data}"
		| 503 =>
			type: @types.fatal
			msg: "Service Unavailable: #{data}"
		| _   =>
			type: @types.error
			msg: "Error: #{data}"

	error-types: http-error.types
	/*
	Load the 'terms of use and disclaimer' from server
	*/
	terms-of-use: (taker) !->
		http('GET', "assets/terms-of-use.txt") taker, (error) !->
			$ionicPopup.alert do
				title: 'Server Error'
				template: error.msg
				ok-text: "Exit"
				ok-type: "button-stable"
			.then (res) !-> ionic.Platform.exitApp!
	/*
	Login to Server
	*/
	login: (way, token, ticket-taker, error-taker) !->
		$log.debug "Login to server with #{way} by #{token}"
		http('POST', "login/#{way}",
			token: token
		) ticket-taker, error-taker
	/*
	Get start session by server, then pass to taker
	*/
	start-session: (ticket, geoinfo) -> (session-taker, error-taker) !->
		$log.debug "Starting session by #{ticket} on #{angular.toJson geoinfo}"
		http('POST', "report/new-session/#{ticket}",
			geoinfo: geoinfo
		) session-taker, error-taker
	/*
	Put a photo which is encoded by base64 to session
	*/
	put-photo: (session, ...photos) -> (success-taker, error-taker) !->
		$log.debug "Putting a photo with #{session}: #{photos}"
		http('POST', "report/photo/#{session}",
			names: photos
		) success-taker, error-taker
	/*
	Put a photo which is encoded by base64 to session
	*/
	infer-photo: (session) -> (success-taker, error-taker) !->
		$log.debug "Inferring a photo with #{session}"
		http('GET', "report/infer/#{session}") success-taker, error-taker
	/*
	Put given report to the session
	*/
	submit-report: (session, report) -> (success, error-taker) !->
		$log.debug "Submitting report with #{session}: #{angular.toJson report}"
		http('POST', "report/submit/#{session}",
			report: report
		) success, error-taker
	/*
	Put given report to the session
	*/
	publish-report: (session, publishing) -> (success, error-taker) !->
		$log.debug "Publishing report with #{session}: #{angular.toJson publishing}"
		http('POST', "report/publish/#{session}",
			publishing: publishing
		) success, error-taker
	/*
	Load report from server, then pass to taker
	*/
	load-reports: (ticket, count, last-id) -> (taker, error-taker) !->
		$log.debug "Loading #{count} reports from #{last-id}"
		http('POST', "report/load/#{ticket}",
			count: count
			last: last-id
		) angular.fromJson >> taker, error-taker
	/*
	Remove report from server
	*/
	remove-report: (ticket, id) -> (success, error-taker) !->
		$log.debug "Removing report(#{id})"
		http('POST', "report/remove/#{ticket}",
			id: id
		) success, error-taker
	/*
	Update report to server. ID has to be contain given report.
	*/
	update-report: (ticket, report) -> (success, error-taker) !->
		$log.debug "Updating report: #{angular.toJson report}"
		http('POST', "report/update/#{ticket}",
			report: report
		) success, error-taker
	/*
	Load units in account settings
	*/
	load-units: (ticket) -> (success, error-taker) !->
		$log.debug "Loading unit"
		http('GET', "account/unit/load/#{ticket}") success, error-taker
	/*
	Update units in account settings
	*/
	change-units: (ticket, unit) -> (success, error-taker) !->
		$log.debug "Changing unit: #{angular.toJson unit}"
		http('POST', "account/unit/change/#{ticket}",
			unit: unit
		) success, error-taker
	/*
	Load distributions of own catches
	*/
	catches-mine: (ticket) -> (success, error-taker) !->
		$log.debug "Retrieving my cathces distributions"
		http('GET', "distribution/mine/#{ticket}") success, error-taker
	/*
	Load distributions of all catches that includes others
	*/
	catches-others: (ticket) -> (success, error-taker) !->
		$log.debug "Retrieving others cathces distributions"
		http('GET', "distribution/others/#{ticket}") success, error-taker
	/*
	Load names of catches with it's count
	*/
	catches-names: (ticket) -> (success, error-taker) !->
		$log.debug "Retrieving names of catches"
		http('GET', "distribution/names/#{ticket}") success, error-taker

.factory 'LocalStorageFactory', ($log) ->
	names = []
	make = (name, isJson = false) ->
		loader = switch isJson
		| true => (v) -> angular.fromJson v
		| _    => (v) -> v
		saver = switch isJson
		| true => (v) -> angular.toJson v
		| _    => (v) -> v

		names.push name

		load: -> 
			v = window.localStorage[name] ? null
			$log.debug "localStorage['#{name}'] => #{v}"
			if v then loader(v)	else null
		save: (v) ->
			value = if v then saver(v) else null
			$log.debug "localStorage['#{name}'] <= #{value}"
			window.localStorage[name] = value
			v
		remove: !->
			window.localStorage.removeItem name

	clear-all: !-> for name in names
		window.localStorage.removeItem name
	/*
	List of String value to express the way of login
	*/
	login-way: make 'login-way'
	/*
	Boolean value for acceptance of 'Terms Of Use and Disclaimer'
	*/
	acceptance: make 'Acceptance'

.factory 'SocialFactory', ($log) ->
	facebook = (...perm) -> (token-taker, error-taker) !->
		$log.info "Logging in to Facebook: #{perm}"
		facebookConnectPlugin.login perm
			, (data) !-> token-taker data.authResponse.accessToken
			, error-taker
	google = (...perm) -> (token-taker, error-taker) !->
		# TODO

	ways:
		facebook: 'facebook'
		google: 'google'
	facebook:
		login: facebook 'basic_info'
		publish: facebook 'publish_actions'
	google:
		login: google 'email'
		publish: google 'publish'

.factory 'SessionFactory', ($log, $ionicPopup, ServerFactory, SocialFactory, ReportFactory, TicketFactory) ->
	store =
		session: null
		upload-info: null

	permit-publish = (way, token-taker, error-taker) !->
		| SocialFactory.ways.facebook => SocialFactory.facebook.publish token-taker, error-taker
		| _             => ionic.Platform.exitApp!

	publish = (session, way) !->
		permit-publish way
		, (token) !->
			ServerFactory.publish-report(session,
				way: way
				token: token
			) !->
				$log.info "Success to publish session: #{session}"
			, (error) !->
				$ionicPopup.alert do
					title: 'Error'
					template: "Failed to publish to #{way}"
		, (error) !->
			$ionicPopup.alert do
				title: 'Rejected'
				template: error

	submit = (session, report, success) !->
		ServerFactory.submit-report(session, report) (report-id) !->
			report.id = report-id
			ReportFactory.add report
			success!
		, (error) !->
			store.session = null
			$ionicPopup.alert do
				title: 'Error'
				template: error.msg

	upload = (uri, success, error) !->
		filename = _.head _.reverse uri.toString!.split('/')
		new FileTransfer().upload uri, store.upload-info.url
			, (e) !->
				$log.info "Success to upload: #{angular.toJson e}"
				success filename
			, (e) !->
				$log.error "Failed to upload: #{angular.toJson e}"
				error e
			,
				fileKey: 'file'
				fileName: filename
				mimeType: 'image/jpeg'
				chunkedMode: false
				params: angular.copy store.upload-info.params

	start: (geoinfo, success, error-taker) !->
		store.session = null
		TicketFactory.get (ticket) ->
			ServerFactory.start-session ticket, geoinfo
		, (result) !->
			store.session = result.session
			store.upload-info = result.upload
			success!
		, (-> it.msg) >> error-taker
	put-photo: (uri, success, inference-taker, error-taker) !->
		if store.session
			upload uri
				, (filename)!->
					ServerFactory.put-photo(that, filename) (urls) !->
						ServerFactory.infer-photo(that) inference-taker, (error) !->
							store.session = null
							error-taker error
						success urls
					, (error) !->
						store.session = null
						error-taker error.msg
				, (error) !->
					error-taker "Failed to upload"
		else error-taker "No session started"
	finish: (report, publish-way, success) !->
		if (session = store.session)
			store.session = null
			submit session, report, !->
				publish(session, publish-way) if publish-way?.length > 0
				success!
		else error-taker "No session started"

.factory 'TicketFactory', ($log, $ionicPopup, AccountFactory, ServerFactory) ->
	store =
		ticket: null

	expirable = (proc, success, error-taker) !->
		take-it = (ticket) !->
			store.ticket = ticket
			proc(ticket) success, (error) !->
				if error.type != ServerFactory.error-types.expired
				then error-taker error
				else
					store.ticket = null
					doit!
		doit = !->
			if store.ticket
			then take-it(that)
			else AccountFactory.login take-it
		doit!

	get: expirable

.factory 'AccountFactory', ($log, $ionicPopup, AcceptanceFactory, LocalStorageFactory, ServerFactory, SocialFactory) ->
	store =
		taking: null
		ticket: null

	wayGet = (way) !->
		if store.taking
			store.taking = null
			for taker in that
				taker way
	doGetLoginWay = !->
		if LocalStorageFactory.login-way.load! then wayGet that
		else AcceptanceFactory.obtain !->
			$log.warn "Taking Login Way ..."
			$ionicPopup.show do
				template: 'Select for Login'
				buttons:
					{
						text: ''
						type: 'button icon ion-social-facebook button-positive'
						onTap: (e) -> SocialFactory.ways.facebook
					},{
						text: ''
						type: 'button icon ion-social-googleplus button-assertive'
						onTap: (e) -> SocialFactory.ways.google
					}
			.then wayGet
	getLoginWay = (way-taker) !->
		if store.taking
			store.taking.push way-taker
		else
			store.taking = [way-taker]
			doGetLoginWay!

	doLogin = (token-taker, error-taker) !->
		getLoginWay (way) !-> switch way
		| SocialFactory.ways.facebook => SocialFactory.facebook.login token-taker(way), error-taker
		| _                           => ionic.Platform.exitApp!

	login: (ticket-taker) !->
		error-taker = (error-msg) !->
			$ionicPopup.alert do
				title: 'Error'
				template: error-msg
			.then (res) !-> action!
		token-taker = (way-name) -> (token) !->
			LocalStorageFactory.login-way.save way-name
			ServerFactory.login way-name, token, ticket-taker, (error) !->
				if error.type != ServerFactory.error-types.fatal
					error-taker error.msg
		action = !-> doLogin token-taker, error-taker
		action!

.factory 'AcceptanceFactory', ($log, $rootScope, $ionicModal, $ionicPopup, LocalStorageFactory, ServerFactory) ->
	store =
		taking: null

	scope = $rootScope.$new(true)
	scope.accept = !->
		$log.info "Acceptance obtained"
		LocalStorageFactory.acceptance.save true
		scope.modal.remove!
		successIt!
	scope.reject = !->
		$ionicPopup.alert do
			title: "Good Bye !"
			ok-text: "Exit"
			ok-type: "button-stable"
		.then (res) !->
			ionic.Platform.exitApp!

	successIt = !->
		if store.taking
			store.taking = null
			for suc in that
				suc!
	takeIt = !->
		if LocalStorageFactory.acceptance.load!
		then successIt!
		else ServerFactory.terms-of-use (text) !->
			scope.terms-of-use = text
			$log.warn "Taking Acceptance ..."
			$ionicModal.fromTemplateUrl 'template/terms-of-use.html'
			, (modal) !->
				scope.modal = modal
				modal.show!
			,
				scope: scope
				animation: 'slide-in-up'
	obtain: (success) !->
		if store.taking
			taking.push success
		else
			store.taking = [success]
			takeIt!

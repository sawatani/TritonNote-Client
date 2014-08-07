.controller 'SettingsCtrl', ($log, $scope, $ionicModal, UnitFactory) !->
	$ionicModal.fromTemplateUrl 'template/settings.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-up'
	$scope.open = !->
		clear!
		$scope.modal.show!
	$scope.cancel = !->
		$scope.modal.hide!
	$scope.submit = !->
		UnitFactory.save $scope.settings.unit
		$scope.modal.hide!

	$scope.checkGoogle = !->
		$scope.account.social.google.connected = true unless $scope.account.forLogin != $scope.account.social.google.title
		$scope.account.social.google.email = if $scope.account.social.google.connected then "google@triton-note.org" else null
	$scope.checkFacebook = !->
		$scope.account.social.facebook.connected = true unless $scope.account.forLogin != $scope.account.social.facebook.title
		$scope.account.social.facebook.email = if $scope.account.social.facebook.connected then "facebook@triton-note.org" else null

	clear = !->
		$scope.units = UnitFactory.units!
		UnitFactory.load (units) !->
			$scope.unit = units
		$scope.account =
			forLogin: "Google+"
			enabled: ->
				[obj.title for key, obj of $scope.account.social when obj.connected]
			social:
				google:
					title: 'Google+'
					connected: true
					email: "google@triton-note.org"
				facebook:
					title: 'Facebook'
					connected: false
					email: null

.controller 'ShowReportsCtrl', ($log, $scope, $ionicModal, $ionicPopup, ReportFactory) !->
	$ionicModal.fromTemplateUrl 'template/show-report.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-up'

	$scope.reports = ReportFactory.cachedList
	$scope.hasMoreReports = ReportFactory.hasMore
	$scope.refresh = !->
		ReportFactory.refresh !->
			$scope.$broadcast 'scroll.refreshComplete'
	$scope.moreReports = !->
		ReportFactory.load !->
			$scope.$broadcast 'scroll.infiniteScrollComplete'
	ionic.Platform.ready !->
		$scope.$apply ReportFactory.clear

	$scope.detail = (index) !->
		$scope.index = index
		$scope.report = ReportFactory.getReport index
		$scope.modal.show!
	$scope.close = !-> $scope.modal.hide!
	$scope.delete = (index) !->
		$ionicPopup.confirm do
			title: "Delete Report"
			template: "Are you sure to delete this report ?"
		.then (res) !-> if res
			ReportFactory.remove index, !->
				$log.debug "Remove completed."
			$scope.modal.hide!

.controller 'DetailReportCtrl', ($log, $scope, $ionicModal, ReportFactory) !->
	$ionicModal.fromTemplateUrl 'template/view-on-map.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-left'

	$scope.showMap = !->
		$scope.modal.show!.then !->
			$scope.gmap-center = $scope.report.location.geoinfo
			$scope.gmap-visible = true
	$scope.closeMap = !->
		$scope.gmap-visible = false
		$scope.modal.hide!

.controller 'EditReportCtrl', ($log, $filter, $scope, $rootScope, $ionicModal, $ionicListDelegate, ReportFactory) !->
	# $scope.report = 表示中のレコード
	# $scope.index = 表示中のレコードの index
	$ionicModal.fromTemplateUrl 'template/edit-report.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-up'

	$ionicModal.fromTemplateUrl 'template/view-on-map.html'
		, (modal) !-> $scope.modal-gmap = modal
		,
			scope: $scope
			animation: 'slide-in-left'

	$scope.title = "Edit Report"

	$scope.showMap = !->
		$scope.modal-gmap.show!.then !->
			$scope.gmap-center = $scope.report.location.geoinfo
			$scope.gmap-visible = true
	$scope.closeMap = !->
		$scope.report.location.geoinfo = $scope.gmap-center
		$scope.submitMap!
	$scope.submitMap = !->
		$scope.gmap-visible = false
		$scope.modal-gmap.hide!
	$scope.gmap-markers = []
	$scope.gmap-onTap = (marker, gi) !->
		if $scope.gmap-markers?.length > 0 then
			for m in $scope.gmap-markers
				if m != marker then
					m.remove!
		$scope.gmap-markers = [marker]
		$log.debug "Set location: #{angular.toJson gi}"
		$scope.report.location.geoinfo = gi

	$scope.edit = !->
		$scope.currentReport = angular.copy $scope.report
		$scope.report.dateAt = $filter('date') new Date($scope.report.dateAt), 'yyyy-MM-dd'
		$scope.modal.show!

	$scope.cancel = !->
		angular.copy $scope.currentReport, $scope.report
		$scope.modal.hide!
	
	$scope.submit = !->
		$scope.currentReport = null
		ReportFactory.update $scope.report, !->
			$log.debug "Edit completed."
		$scope.modal.hide!

.controller 'AddReportCtrl', ($log, $filter, $scope, $rootScope, $ionicModal, $ionicPopup, PhotoFactory, ReportFactory, SessionFactory, LocalStorageFactory) !->
	$ionicModal.fromTemplateUrl 'template/edit-report.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-up'

	$ionicModal.fromTemplateUrl 'template/view-on-map.html'
		, (modal) !-> $scope.modal-gmap = modal
		,
			scope: $scope
			animation: 'slide-in-left'

	$scope.title = "New Report"
	$scope.publish =
		do: {}
		ables: []

	newReport = (uri, geoinfo) ->
		photo:
			mainview: uri
		dateAt: $filter('date') new Date!, 'yyyy-MM-dd'
		location:
			name: "Here"
			geoinfo: geoinfo
		fishes: []
		comment: ""

	$scope.open = !->
		start = (geoinfo = null) !->
			SessionFactory.start geoinfo
			, !->
				PhotoFactory.select (uri) !->
					SessionFactory.put-photo uri, (result) !->
						$log.debug "Get result of upload: #{angular.toJson result}"
						$scope.report.photo = result.url
						$scope.unsubmittable = false
					, (inference) !->
						$log.debug "Get inference: #{angular.toJson inference}"
						if inference.location
							$scope.report.location.name = that
						if inference.fishes && inference.fishes.length > 0
							$scope.report.fishes = inference.fishes
					, (error) !->
						$ionicPopup.alert do
							title: "Failed to upload"
							template: error
						.then (res) !->
							$scope.modal.hide!
					$scope.$apply !->
						$scope.publish.ables = if LocalStorageFactory.login-way.load! then [that.name] else []
						imageUrl = if device.platform == 'Android'
							then ""
							else uri
						$scope.report = newReport imageUrl, geoinfo
					$scope.unsubmittable = true
					$scope.modal.show!
				, (msg) !->
					$ionicPopup.alert do
						title: "No photo selected"
						template: "Need a photo to report"
			, (error) !->
				$ionicPopup.alert do
					title: "Error"
					template: error
		navigator.geolocation.getCurrentPosition do
			(pos) !->
				$log.debug "Gotta geolocation: #{angular.toJson pos}"
				start do
					latitude: pos.coords.latitude
					longitude: pos.coords.longitude
			, (error) !->
				$log.error "Geolocation Error: #{angular.toJson error}"
				start!

	$scope.showMap = !->
		$scope.modal-gmap.show!.then !->
			$scope.gmap-center = $scope.report.location.geoinfo
			$scope.gmap-visible = true
	$scope.closeMap = !->
		$scope.report.location.geoinfo = $scope.gmap-center
		$scope.submitMap!
	$scope.submitMap = !->
		$scope.gmap-visible = false
		$scope.modal-gmap.hide!
	$scope.gmap-markers = []
	$scope.gmap-onTap = (marker, gi) !->
		if $scope.gmap-markers?.length > 0 then
			for m in $scope.gmap-markers
				if m != marker then
					m.remove!
		$scope.gmap-markers = [marker]
		$log.debug "Set location: #{angular.toJson gi}"
		$scope.report.location.geoinfo = gi

	$scope.cancel = !-> $scope.modal.hide!
	$scope.submit = !->
		report = angular.copy $scope.report
		report.dateAt = new Date(report.dateAt).getTime!
		SessionFactory.finish report, [name for name, value of $scope.publish.do when value][0], !->
			$log.debug "Success on submitting report"
		$scope.modal.hide!

.controller 'AddFishCtrl', ($scope, $ionicModal, $ionicPopup, UnitFactory) !->
	# $scope.report.fishes
	fish-template = (o = null) ->
		r =
			name: null
			count: 1
		r <<< o if o
		r.length = {} unless r.length
		r.weight = {} unless r.weight
		UnitFactory.load (units) !->
			r.length.unit = units.length
			r.weight.unit = units.weight
		r
	$ionicModal.fromTemplateUrl 'template/edit-fish.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-up'

	show = (func) !->
		$scope.commit = func
		$scope.modal.show!

	$scope.cancel = !->
		$scope.fishIndex = null
		$scope.tmpFish = null
		$scope.modal.hide!
	$scope.submit = !->
		fish = $scope.tmpFish
		if fish.name?.length > 0 && fish.count > 0
		then
			fish.length = null unless fish.length.value
			fish.weight = null unless fish.weight.value
			$scope.commit fish
			$scope.commit = null
			$scope.fishIndex = null
			$scope.tmpFish = null
			$scope.modal.hide!

	$scope.units = UnitFactory.units!
	$scope.addFish = !->
		$scope.tmpFish = fish-template!
		show (fish) !-> $scope.report.fishes.push fish
	$scope.editFish = (index) !->
		$scope.fishIndex = index
		$scope.tmpFish = fish-template $scope.report.fishes[index]
		show (fish) !-> $scope.report.fishes[index] <<< fish
	$scope.deleteFish = (index, confirm = true) !->
		del = !-> $scope.report.fishes.splice index, 1
		if !confirm then del! else
			$ionicPopup.confirm do
				template: "Are you sure to delete this catch ?"
			.then (res) !-> if res
				$scope.modal.hide!
				del!

.controller 'DistributionMapCtrl', ($log, $scope, $filter, $ionicModal, $ionicPopup, DistributionFactory, ReportFactory) !->
	$ionicModal.fromTemplateUrl 'template/distribution-map.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-left'
	$scope.gmap = null
	$scope.setGmap = (gmap) !->
		$log.debug "Setting GMap:#{gmap}"
		$scope.gmap = gmap
		map-distribution!
	$scope.open = !->
		$scope.modal.show!.then !->
			$scope.gmap-visible = true
	$scope.closeMap = !->
		$scope.gmap-visible = false
		$scope.modal.hide!

	$scope.persons =
		mine:
			icon: 'ion-ios7-person'
			next: 'mine and others'
		'mine and others':
			icon: 'ion-ios7-people'
			next: 'mine'
	$scope.view =
		person: 'mine'
		fish: ''
	$scope.person = -> $scope.persons[$scope.view.person]

	$scope.$watch 'view.person', (value) !->
		$log.debug "Changing 'view.person': #{angular.toJson value}"
		map-distribution!

	$scope.$watch 'view.fish', (value) !->
		$log.debug "Changing 'view.fish': #{angular.toJson value}"
		map-distribution!

	$ionicModal.fromTemplateUrl 'template/show-report.html'
		, (modal) !-> $scope.modal-detail = modal
		,
			scope: $scope
			animation: 'slide-in-up'

	$scope.close = !->
		$scope.modal-detail.hide!
		$scope.gmap-visible = true
	$scope.delete = (index) !->
		$ionicPopup.confirm do
			title: "Delete Report"
			template: "Are you sure to delete this report ?"
		.then (res) !-> if res
			ReportFactory.remove index, !->
				$log.debug "Remove completed."
			$scope.close!

	icons = _.map (count) ->
		size = 32
		center = size / 2
		r = ->
			min = 4
			max = center - 1
			v = min + (max - min) * count / 10
			_.min max, v
		canvas = document.createElement 'canvas'
		canvas.width = size
		canvas.height = size
		context = canvas.getContext '2d'
		context.beginPath!
		context.strokeStyle = "rgb(80, 0, 0)"
		context.fillStyle = "rgba(255, 40, 0, 0.7)"
		context.arc center, center, r!, 0, _.pi * 2, true
		context.stroke!
		context.fill!
		canvas.toDataURL!
	, [1 to 10]
	map-distribution = !->
		gmap = $scope.gmap
		person = $scope.view.person
		fish-name = $scope.view.fish

		map-mine = (list) !->
			$log.debug "Mapping my distribution (filtered by '#{fish-name}'): #{list}"
			gmap.clear!
			detail = (fish) -> (marker) !->
				marker.on plugin.google.maps.event.INFO_CLICK, !->
					$log.debug "Detail for fish: #{angular.toJson fish}"
					find-or = (fail) !->
						$scope.index = ReportFactory.getIndex fish.report-id
						if $scope.index >= 0 then
							$scope.report = ReportFactory.getReport $scope.index
							$scope.gmap-visible = false
							$scope.modal-detail.show!
						else fail!
					find-or !->
						ReportFactory.refresh !->
							find-or !->
								$log.error "Report not found by id: #{fish.report-id}"
			for fish in list
				gmap.addMarker do
					title: "#{fish.name} x #{fish.count}"
					snippet: $filter('date') new Date(fish.date), 'yyyy-MM-dd'
					position:
						lat: fish.geoinfo.latitude
						lng: fish.geoinfo.longitude
					, detail fish
		map-others = (list) !->
			$log.debug "Mapping other's distribution (filtered by '#{fish-name}'): #{list}"
			gmap.clear!
			for fish in list
				gmap.addMarker do
					title: "#{fish.name} x #{fish.count}"
					icon: icons[(_.min fish.count, 10) - 1]
					position:
						lat: fish.geoinfo.latitude
						lng: fish.geoinfo.longitude

		if (gmap) then switch person
		| 'mine'            => DistributionFactory.mine fish-name, map-mine
		| 'mine and others' => DistributionFactory.others fish-name, map-others

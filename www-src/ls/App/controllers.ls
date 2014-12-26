.controller 'SNSCtrl', ($log, $scope, $stateParams, $ionicHistory, $ionicLoading, $ionicPopup, AccountFactory, ReportFactory) !->
	$ionicLoading.show!
	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter SNSCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		AccountFactory.get-username (username) !->
			$scope.$apply !-> $scope.done username
		, (error-msg) !->
			$scope.$apply !-> $scope.done!

	$scope.checkSocial = !->
		$ionicLoading.show!
		next = $scope.social.username == null
		$log.debug "Changing social: #{next}"
		on-error = (error) !->
			$log.error "Erorr on Facebook: #{angular.toJson error}"
			$scope.done $scope.social.username
			$ionicPopup.alert do
				title: "Rejected"
		if next
			AccountFactory.connect $scope.done, on-error
		else
			AccountFactory.disconnect !->
				ReportFactory.clear-list!
				$ionicHistory.clearCache!
				$log.warn "SNSCtrl: Cache Cleared!"
				$scope.done!
				$ionicPopup.alert do
					title: "No social connection"
					template: "Please login to Facebook, if you want to continue this app."
			, on-error
	$scope.done = (username = null) !->
		$scope.social =
			username: username
			login: username != null
		$ionicLoading.hide!
		$log.debug "Account connection: #{angular.toJson $scope.social}"

.controller 'PreferencesCtrl', ($log, $scope, $stateParams, $ionicHistory, $ionicLoading, $ionicPopup, UnitFactory) !->
	$ionicLoading.show!
	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter PreferencesCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		$ionicLoading.show!
		UnitFactory.load (units) !->
			$scope.unit = units
			$ionicLoading.hide!

	$scope.submit = !->
		UnitFactory.save $scope.unit
		$ionicHistory.goBack!
	$scope.units = UnitFactory.units!

.controller 'ListReportsCtrl', ($log, $scope, ReportFactory) !->
	$scope.reports = ReportFactory.cachedList
	$scope.hasMoreReports = ReportFactory.hasMore
	$scope.refresh = !->
		ReportFactory.refresh !->
			$scope.$broadcast 'scroll.refreshComplete'
	$scope.moreReports = !->
		ReportFactory.load !->
			$scope.$broadcast 'scroll.infiniteScrollComplete'

.controller 'ShowReportCtrl', ($log, $stateParams, $ionicHistory, $ionicScrollDelegate, $scope, $ionicPopup, ReportFactory) !->
	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter ShowReportCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		$scope.should-clear = true
		if $stateParams.index && ReportFactory.current!.index == null
			$scope.report = ReportFactory.getReport($scope.index = Number($stateParams.index))
		else
			c = ReportFactory.current!
			$scope.index = c.index
			$scope.report = c.report
		$log.debug "Show Report: #{angular.toJson $scope.report}"
		$ionicScrollDelegate.$getByHandle("scroll-img-show-report").zoomTo 1

	$scope.$on '$ionicView.beforeLeave', (event, state) !->
		$log.debug "Before Leave ShowReportCtrl: event=#{angular.toJson event}: state=#{angular.toJson state}"
		ReportFactory.clear-current! if $scope.should-clear

	$scope.useCurrent = !->
		$scope.should-clear = false
	$scope.delete = !->
		$ionicPopup.confirm do
			title: "Delete Report"
			template: "Are you sure to delete this report ?"
		.then (res) !-> if res
			ReportFactory.remove $scope.index, !->
				$log.debug "Remove completed."
			$ionicHistory.goBack!

.controller 'EditReportCtrl', ($log, $stateParams, $scope, $ionicScrollDelegate, $ionicHistory, ReportFactory) !->
	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter EditReportCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		$scope.should-clear = true
		$scope.report = ReportFactory.current!.report
		$ionicScrollDelegate.$getByHandle("scroll-img-edit-report").zoomTo 1

	$scope.$on '$ionicView.beforeLeave', (event, state) !->
		$log.debug "Before Leave EditReportCtrl: event=#{angular.toJson event}: state=#{angular.toJson state}"
		ReportFactory.clear-current! if $scope.should-clear

	$scope.useCurrent = !->
		$scope.should-clear = false
	$scope.submit = !->
		ReportFactory.updateByCurrent !->
			$log.debug "Edit completed."
			$ionicHistory.goBack!

.controller 'AddReportCtrl', ($log, $timeout, $ionicPlatform, $scope, $stateParams, $ionicHistory, $ionicLoading, $ionicPopover, $ionicPopup, PhotoFactory, SessionFactory, ReportFactory, GMapFactory) !->
	$log.debug "Init AddReportCtrl"
	$ionicLoading.show!
	$scope.$on '$ionicView.loaded', (event, state) !->
		$log.debug "Loaded AddReportCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"

		$ionicPopover.fromTemplateUrl 'confirm-submit',
			scope: $scope
		.then (popover) !->
			$scope.confirm-submit = popover
		$ionicPopover.fromTemplateUrl 'choose-tide',
			scope: $scope
		.then (popover) !->
			$scope.choose-tide = popover
		$ionicPopover.fromTemplateUrl 'range-moon',
			scope: $scope
		.then (popover) !->
			$scope.range-moon = popover

		$scope.$watch 'report.tide', (new-value, old-value) !->
			$timeout !->
				$scope.choose-tide.hide!
			, 500
		$scope.$watch 'report.dateAt', (new-value, old-value) !->
			ReportFactory.moon new-value, (moon) !->
				$scope.report.moon = moon
			ReportFactory.tide new-value, (tide) !->
				$scope.report.tide = tide

		$scope.tide-phases = ['Flood', 'High', 'Ebb', 'Low']
		$scope.tide =
			Flood: "http://farmersalmanac.com/wp-content/plugins/moon-phase-widget/moon-img/54/0.jpg"
			High: "http://farmersalmanac.com/wp-content/plugins/moon-phase-widget/moon-img/54/3.jpg"
			Ebb: "http://farmersalmanac.com/wp-content/plugins/moon-phase-widget/moon-img/54/6.jpg"
			Low: "http://farmersalmanac.com/wp-content/plugins/moon-phase-widget/moon-img/54/9.jpg"
		$scope.moon = [
			"http://farmersalmanac.com/wp-content/plugins/moon-phase-widget/moon-img/54/9.jpg"
		]

	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter AddReportCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		$scope.should-clear = true

		if ReportFactory.current!.report
			$ionicLoading.hide!
			$scope.report = that
			$log.debug "Getting current report: #{angular.toJson $scope.report}"
			$scope.submission.enabled = !!$scope.report.photo.original
		else
			on-error = (title) -> (error-msg) !->
				$ionicLoading.hide!
				$ionicPopup.alert do
					title: title
					template: error-msg
				.then $ionicHistory.goBack
			PhotoFactory.select (info, photo) !->
				uri = URL.createObjectURL photo
				console.log "Selected photo info: #{angular.toJson info}: #{uri}"
				upload = (geoinfo = null) !->
					$scope.report = ReportFactory.newCurrent uri, info?.timestamp ? new Date!, geoinfo
					$log.debug "Created report: #{angular.toJson $scope.report}"
					SessionFactory.start geoinfo, !->
						$ionicLoading.hide!
						SessionFactory.put-photo photo
						, (result) !->
							$log.debug "Get result of upload: #{angular.toJson result}"
							$scope.submission.enabled = true
							$timeout !->
								$log.debug "Updating photo url: #{result.url}"
								$scope.report.photo <<< result.url
							, 1000
						, (inference) !->
							$log.debug "Get inference: #{angular.toJson inference}"
							if inference.location
								$scope.report.location.name = that
							if inference.fishes?.length > 0
								$scope.report.fishes = inference.fishes
						, on-error "Failed to upload"
					, on-error "Error"
				if info?.geoinfo
					upload info.geoinfo
				else
					$log.warn "Getting current location..."
					GMapFactory.getGeoinfo upload, (error) !->
						$log.error "Geolocation Error: #{angular.toJson error}"
						upload!
			, on-error "Need one photo"

	$scope.$on '$ionicView.beforeLeave', (event, state) !->
		$log.debug "Before Leave AddReportCtrl: event=#{angular.toJson event}: state=#{angular.toJson state}"
		ReportFactory.clear-current! if $scope.should-clear

	$scope.useCurrent = !->
		$scope.should-clear = false
	$scope.submit = !->
		$ionicLoading.show!
		SessionFactory.finish $scope.report, $scope.submission.publishing, !->
			$ionicHistory.goBack!
			$ionicLoading.hide!
	$scope.submission =
		enabled: false
		publishing: false

.controller 'AddFishCtrl', ($log, $scope, $ionicPopover, UnitFactory) !->
	# $scope.report.fishes
	$scope.units = UnitFactory.units!
	$scope.user-units =
		length: 'cm'
		weight: 'kg'
	UnitFactory.load (units) !->
		$scope.user-units <<< units

	$ionicPopover.fromTemplateUrl 'edit-fish',
		scope: $scope
	.then (popover) !->
		$scope.edit-pop = popover
	$scope.adding =
		name: null
	$scope.addFish = !->
		$log.debug "Adding fish: #{$scope.adding.name}"
		if !!$scope.adding.name
			$scope.report.fishes.push do
				name: $scope.adding.name
				count: 1
				length:
					value: null
					unit: $scope.user-units.length
				weight:
					value: null
					unit: $scope.user-units.weight
			$scope.adding.name = null
	$scope.editFish = (event, index) !->
		$log.debug "Editing fish: #{index}"
		$scope.current = $scope.report.fishes[index]
		$scope.tmpFish = angular.copy $scope.current
		$scope.edit-pop.show event
	$scope.$on 'popover.hidden', !->
		$log.debug "Hide popover"
		if $scope.tmpFish.name && $scope.tmpFish.count
			$scope.current <<< $scope.tmpFish

.controller 'ReportOnMapCtrl', ($log, $scope, $state, $stateParams, $ionicHistory, $ionicPopover, GMapFactory, ReportFactory) !->
	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter ReportOnMapCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		$scope.report = ReportFactory.current!.report
		GMapFactory.onDiv $scope, 'edit-map', (gmap) !->
			$scope.$on 'popover.hidden', !->
				gmap.setClickable true
			$scope.showViewOptions = (event) !->
				gmap.setClickable false
				$scope.popover-view.show event
			if $stateParams.edit
				$scope.geoinfo = $scope.report.location.geoinfo
				GMapFactory.onTap (geoinfo) !->
					$scope.geoinfo = geoinfo
					GMapFactory.put-marker geoinfo
		, $scope.report.location.geoinfo
		$scope.view =
			gmap:
				type: GMapFactory.getMapType!
				types: GMapFactory.getMapTypes!
		$scope.$watch 'view.gmap.type', (value) !->
			$log.debug "Changing 'view.gmap.type': #{angular.toJson value}"
			GMapFactory.setMapType value
		$ionicPopover.fromTemplateUrl 'view-map-view',
			scope: $scope
		.then (pop) ->
			$scope.popover-view = pop

	$scope.submit = !->
		if $scope.geoinfo
			$scope.report.location.geoinfo = that
		$ionicHistory.goBack!

.controller 'DistributionMapCtrl', ($log, $ionicPlatform, $scope, $state, $stateParams, $ionicSideMenuDelegate, $ionicPopover, $ionicLoading, GMapFactory, DistributionFactory, ReportFactory) !->
	$ionicLoading.show!
	$scope.$on '$ionicView.loaded', (event, state) !->
		$log.debug "Loaded DistributionMapCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		$scope.view =
			others: false
			name: null
			gmap:
				type: GMapFactory.getMapType!
				types: GMapFactory.getMapTypes!
		$scope.$watch 'view.others', (value) !->
			$log.debug "Changing 'view.person': #{angular.toJson value}"
			$scope.map-distribution!
		$scope.$watch 'view.name', (value) !->
			$log.debug "Changing 'view.fish': #{angular.toJson value}"
			$scope.map-distribution!
		$scope.$watch 'view.gmap.type', (value) !->
			$log.debug "Changing 'view.gmap.type': #{angular.toJson value}"
			GMapFactory.setMapType value
		$ionicPopover.fromTemplateUrl 'distribution-map-options',
			scope: $scope
		.then (pop) ->
			$scope.popover-options = pop
		$scope.showOptions = (event) !->
			$scope.gmap.setClickable false
			$scope.popover-options.show event
		$ionicPopover.fromTemplateUrl 'distribution-map-view',
			scope: $scope
		.then (pop) ->
			$scope.popover-view = pop
		$scope.showViewOptions = (event) !->
			$scope.gmap.setClickable false
			$scope.popover-view.show event
		$scope.$on 'popover.hidden', !->
			$scope.gmap.setClickable true

		icons = [1 to 10] |> _.map (count) ->
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
		$scope.map-distribution = !-> if gmap = $scope.gmap
			others = $scope.view.others
			fish-name = $scope.view.name
			map-mine = (list) !->
				$log.debug "Mapping my distribution (filtered by '#{fish-name}'): #{list}"
				gmap.clear!
				detail = (fish) -> (marker) !->
					marker.on plugin.google.maps.event.INFO_CLICK, !->
						$log.debug "Detail for fish: #{angular.toJson fish}"
						find-or = (fail) !->
							index = ReportFactory.getIndex fish.report-id
							if index >= 0 then
								GMapFactory.clear!
								$state.go 'show-report',
									index: index
							else fail!
						find-or !->
							ReportFactory.refresh !->
								find-or !->
									$log.error "Report not found by id: #{fish.report-id}"
				for fish in list
					gmap.addMarker do
						title: "#{fish.name} x #{fish.count}"
						snippet: fish.date.toLocaleDateString!
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
			if !others
			then DistributionFactory.mine fish-name, map-mine
			else DistributionFactory.others fish-name, map-others

	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter DistributionMapCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		$ionicLoading.show!
		GMapFactory.onDiv $scope, 'distribution-map', (gmap) !->
			$scope.gmap = gmap
			$scope.map-distribution!
			$ionicLoading.hide!

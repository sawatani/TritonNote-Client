.controller 'SNSCtrl', ($log, $scope, $stateParams, $ionicPopup, AccountFactory) !->
	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter SNSCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		AccountFactory.get-username (username) !->
			$scope.$apply !-> $scope.done username
		, (error-msg) !->
			$scope.$apply !-> $scope.done!

	$scope.checkSocial = !->
		$scope.changing = true
		next = $scope.social.username == null
		$log.debug "Changing social: #{next}"
		on-error = (error) !->
			$log.error "Erorr on Facebook: #{angular.toJson error}"
			$ionicPopup.alert do
				title: "Error"
			.then !->
				$scope.done $scope.social.username
		if next
			AccountFactory.connect $scope.done, on-error
		else
			AccountFactory.disconnect !->
				$ionicPopup.alert do
					title: "No social connection"
					template: "Please login to Facebook, if you want to continue this app."
				.then !-> $scope.done!
			, on-error
	$scope.done = (username = null) !->
		$scope.social =
			username: username
			login: username != null
		$scope.changing = false
		$log.debug "Account connection: #{angular.toJson $scope.social}"

.controller 'PreferencesCtrl', ($log, $scope, $stateParams, $ionicHistory, $ionicPopup, UnitFactory) !->
	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter PreferencesCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		UnitFactory.load (units) !->
			$scope.unit = units

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

	$scope.openMap = !->
		$log.debug "Click open map !!"
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
		$scope.report.dateAt = ReportFactory.format-date $scope.report.dateAt
		$ionicScrollDelegate.$getByHandle("scroll-img-edit-report").zoomTo 1

	$scope.$on '$ionicView.beforeLeave', (event, state) !->
		$log.debug "Before Leave EditReportCtrl: event=#{angular.toJson event}: state=#{angular.toJson state}"
		ReportFactory.clear-current! if $scope.should-clear

	$scope.openMap = !->
		$log.debug "Click open map !!"
		$scope.should-clear = false
	$scope.submit = !->
		ReportFactory.updateByCurrent !->
			$log.debug "Edit completed."
			$ionicHistory.goBack!

.controller 'AddReportCtrl', ($log, $ionicPlatform, $scope, $stateParams, $ionicHistory, $ionicPopup, $ionicScrollDelegate, PhotoFactory, SessionFactory, ReportFactory, GMapFactory) !->
	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter AddReportCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		$scope.should-clear = true
		if ReportFactory.current!.report
			$scope.report = that
			$log.debug "Getting current report: #{angular.toJson $scope.report}"
			$scope.submission.enabled = !!$scope.report.photo.original
		else
			on-error = (title) -> (error-msg) !->
				$ionicPopup.alert do
					title: title
					template: error-msg
				.then $ionicHistory.goBack
			PhotoFactory.select (photo) !->
				uri = if photo instanceof Blob then URL.createObjectURL(photo) else photo
				$log.debug "Selected photo: #{uri}"
				$ionicScrollDelegate.$getByHandle("scroll-img-add-report").zoomTo 1
				$scope.report = ReportFactory.newCurrent uri
				upload = (geoinfo = null) !->
					$scope.report.location.geoinfo = geoinfo
					SessionFactory.start geoinfo, !->
						SessionFactory.put-photo photo
						, (result) !->
							$log.debug "Get result of upload: #{angular.toJson result}"
							$scope.report.photo <<< result.url
							$scope.submission.enabled = true
						, (inference) !->
							$log.debug "Get inference: #{angular.toJson inference}"
							if inference.location
								$scope.report.location.name = that
							if inference.fishes?.length > 0
								$scope.report.fishes = inference.fishes
						, on-error "Failed to upload"
					, on-error "Error"
				$log.warn "Getting current location..."
				GMapFactory.getGeoinfo upload, (error) !->
					$log.error "Geolocation Error: #{angular.toJson error}"
					upload!
			, on-error "Need one photo"

	$scope.$on '$ionicView.beforeLeave', (event, state) !->
		$log.debug "Before Leave AddReportCtrl: event=#{angular.toJson event}: state=#{angular.toJson state}"
		ReportFactory.clear-current! if $scope.should-clear

	$scope.openMap = !->
		$log.debug "Click open map !!"
		$scope.should-clear = false
	$scope.submit = !->
		report = $scope.report
		report.dateAt = new Date(report.dateAt).getTime!
		SessionFactory.finish report, $scope.submission.publishing, !->
			$ionicHistory.goBack!
	$scope.submission =
		enabled: false
		publishing: false

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
	$ionicModal.fromTemplateUrl 'edit-fish'
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

.controller 'ReportOnMapCtrl', ($log, $scope, $state, $stateParams, $ionicHistory, GMapFactory, ReportFactory) !->
	$scope.$on '$ionicView.enter', (event, state) !->
		$log.debug "Enter ReportOnMapCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		$scope.report = ReportFactory.current!.report
		GMapFactory.onDiv 'edit-map', (gmap) !->
			if $stateParams.edit
				$scope.geoinfo = $scope.report.location.geoinfo
				GMapFactory.onTap (geoinfo) !->
					$scope.geoinfo = geoinfo
					GMapFactory.put-marker geoinfo
		, $scope.report.location.geoinfo

	$scope.submit = !->
		if $scope.geoinfo
			$scope.report.location.geoinfo = that
		$ionicHistory.goBack!

.controller 'DistributionMapCtrl', ($log, $ionicPlatform, $scope, $state, $stateParams, $ionicSideMenuDelegate, $ionicPopup, GMapFactory, DistributionFactory, ReportFactory) !->
	$scope.$on '$ionicView.beforeEnter', (event, state) !->
		$log.debug "Before Enter DistributionMapCtrl: params=#{angular.toJson $stateParams}: event=#{angular.toJson event}: state=#{angular.toJson state}"
		GMapFactory.onDiv 'distribution-map', (gmap) !->
			$scope.gmap = gmap
			$scope.$watch ->
				!!$ionicSideMenuDelegate.isOpenLeft!
			, (isOpen) !->
				$log.debug "DistributionMapCtrl: side menu open: #{isOpen}"
				$scope.gmap.setClickable !isOpen
				document.getElementsByClassName('menu-left')[0].style.display = if isOpen then 'block' else 'none'
			map-distribution!

	$scope.showOptions = !->
		$scope.gmap.setClickable false
		$ionicPopup.alert do
			templateUrl: 'distribution-map-options',
			scope: $scope
			title: "Options"
		.then (res) ->
			$scope.gmap.setClickable true
	$scope.view =
		others: false
		name: null
	$scope.$watch 'view.others', (value) !->
		$log.debug "Changing 'view.person': #{angular.toJson value}"
		map-distribution!
	$scope.$watch 'view.name', (value) !->
		$log.debug "Changing 'view.fish': #{angular.toJson value}"
		map-distribution!

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
	map-distribution = !->
		gmap = $scope.gmap
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
					snippet: ReportFactory.format-date fish.date
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
		if (gmap)
			if !others
			then DistributionFactory.mine fish-name, map-mine
			else DistributionFactory.others fish-name, map-others

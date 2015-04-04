angular.module('triton_note.directive', [])
.directive 'fathensFitImg', ($log, $ionicScrollDelegate) ->
	getProp = (obj, [h, left...]) ->
		next = obj[h]
		if (next and left.length > 0) then getProp(next, left) else next

	restrict: 'E'
	template: '<ion-scroll><div><img/></div></ion-scroll>'
	replace: true
	link: ($scope, $element, $attrs) ->
		div = $element.children().children()[0]
		img = $element.children().children().children()
		photo = $attrs['src']
		whole = !!$attrs['whole']
		if photo and photo.length > 0
			chain = photo.split('.')
			$scope.$watch chain[0], ->
				photoUrl = getProp $scope, chain
				if photoUrl
					$log.debug "fathensFitImg: img=#{img}, photo=#{photo}, src=#{photoUrl}"
					img.attr('src', photoUrl)
					img.on 'load', ->
						rect =
							width: img[0].clientWidth
							height: img[0].clientHeight
						# Fit width
						max = if document.documentElement.clientWidth < document.documentElement.clientHeight then rect.width else rect.height
						div.style.width = "#{Math.min max, rect.width}px"
						div.style.height = "#{Math.min max, rect.height}px"
						$log.debug "fathensFitImg: #{angular.toJson rect} is> #{max}"
						# Scroll to center
						delegate = $ionicScrollDelegate.$getByHandle $attrs['delegateHandle']
						if delegate
							margin = (f) -> if max < f(rect) then (f(rect) - max)/2 else 0
							sc =
								left: margin (v) -> v.width
								top: margin (v) -> v.height
							delegate.scrollTo sc.left, sc.top
							$log.debug "fathensFitImg: scroll=#{angular.toJson sc}"
							minZoom = Math.min 1, if document.documentElement.clientWidth < document.documentElement.clientHeight then rect.width / rect.height else rect.height / rect.width
							if whole and minZoom < 1
								delegate.zoomTo minZoom, true

.directive 'fathensEditReport', ($log) ->
	restrict: 'E'
	templateUrl: 'page/report/editor-report.html'
	replace: true
	controller: ($scope, $element, $attrs, $timeout, $state, $ionicPopover, ConditionFactory, UnitFactory) ->
		$scope.popover = {}
		['spot_location', 'choose_tide', 'choose_weather'].forEach (name) ->
			$ionicPopover.fromTemplateUrl name,
				scope: $scope
			.then (popover) ->
				$scope.popover[name] = popover
		$scope.popoverHide = ->
			for _, p of $scope.popover
				p?.hide()
		$scope.$on '$destroy', (event) ->
			$log.info "Leaving 'fathens-edit-report': #{event}"
			for _, p of $scope.popover
				p?.remove()

		$scope.tideModified = false
		$scope.tideModify = ->
			$log.debug "Condition tide modified by user: #{$scope.report.condition.tide}"
			$scope.tideModified = true
		$scope.weatherModified = false
		$scope.weatherModify = ->
			$log.debug "Condition weather modified by user: #{$scope.report.condition.weather.name}"
			$scope.weatherModified = true
			$timeout ->
				$log.debug "Using weather icon by Name: #{$scope.report.condition.weather.name}"
				$scope.report?.condition?.weather.iconUrl = $scope.weatherIcon($scope.report.condition.weather.name)
			, 200

		$scope.$watch 'report.condition.tide', (newValue, oldValue) ->
			$scope.popover.choose_tide.hide()
		$scope.$watch 'report.condition.weather.temperature.unit', (newValue, oldValue) ->
			$scope.report?.condition?.weather.temperature = UnitFactory.temperature $scope.report.condition.weather.temperature
		$scope.$watch 'report.condition.weather.temperature.value', (newValue, oldValue) ->
			$scope.report?.condition?.weather.temperature.value = Math.round(newValue * 10) / 10
		$scope.$watch 'report.condition.weather.name', (newValue, oldValue) ->
			$scope.popover.choose_weather.hide()

		$scope.$watch 'report.dateAt', (newValue, oldValue) -> if oldValue or !$scope.report?.condition
			changeCondition(newValue, $scope.report?.location?.geoinfo)
		$scope.$watch 'report.location.geoinfo', (newValue, oldValue) -> if oldValue or !$scope.report?.condition
			changeCondition($scope.report?.dateAt, newValue)
		changeCondition = (datetime, geoinfo) -> if datetime and geoinfo
			$scope.report.condition = {} if !$scope.report.condition
			ConditionFactory.state datetime, geoinfo, (state) ->
				$log.debug "Conditions result: #{angular.toJson state}"
				$scope.report.condition.moon = state.moon
				if !$scope.tideModified
					$scope.report.condition.tide = state.tide
				if state.weather
					if !$scope.weatherModified
						$scope.report.condition.weather = state.weather
					else
						$scope.report.condition.weather.temperature = state.weather.temperature

		$scope.moonIcon = -> ConditionFactory.moonPhases[$scope.report?.condition?.moon]
		$scope.tideIcon = -> $scope.tidePhases.filter((v) -> v.name is $scope.report?.condition?.tide).map((v) -> v.icon)[0]
		$scope.weatherIcon = (name) -> $scope.weatherStates[name]

		$scope.tidePhases = ConditionFactory.tidePhases
		$scope.weatherStates = ConditionFactory.weatherStates

		$scope.spotLocationGmap =
			map: null
			marker: null
		$scope.showMap = ($event) ->
			gmap = $scope.spotLocationGmap
			geoinfo = $scope.report.location.geoinfo
			center = new google.maps.LatLng(geoinfo.latitude, geoinfo.longitude)
			$scope.popover.spot_location.show $event
			.then ->
				div = document.getElementById "gmap"
				unless gmap.map
					gmap.map = new google.maps.Map div,
						mapTypeId: google.maps.MapTypeId.HYBRID
						disableDefaultUI: true
				gmap.map.setCenter center
				gmap.map.setZoom 8

				gmap.marker?.setMap null
				gmap.marker = new google.maps.Marker
					title: $scope.report.location.name
					map: gmap.map
					position: center
					animation: google.maps.Animation.DROP

				google.maps.event.addDomListener div, 'click', ->
					$scope.popoverHide()
					$scope.useCurrent()
					$state.go "view-on-map",
						edit: true

.directive 'fathensEditFishes', ($log) ->
	restrict: 'E'
	templateUrl: 'page/report/editor-fishes.html'
	replace: true
	scope: true
	controller: ($scope, $element, $attrs, $timeout, $ionicPopover, UnitFactory) ->
		$ionicPopover.fromTemplateUrl 'fish-edit',
			scope: $scope
		.then (popover) ->
			$scope.fishEdit = popover
		$scope.$on '$destroy', (event) ->
			$log.info "Leaving 'fathens-edit-fishes': #{event}"
			$scope.fishEdit?.remove()
		$scope.units = UnitFactory.units()
		$scope.userUnits =
			length: 'cm'
			weight: 'kg'
		UnitFactory.load (units) ->
			angular.copy units, $scope.userUnits

		$scope.adding =
			name: null
		$scope.addFish = ->
			$log.debug "Adding fish: #{$scope.adding.name}"
			if !!$scope.adding.name
				$scope.report.fishes.push
					name: $scope.adding.name
					count: 1
				$scope.adding.name = null
		$scope.editing = false
		$scope.editFish = (event, index) ->
			$scope.current = $scope.report.fishes[index]
			$scope.tmpFish = angular.copy $scope.current
			if !$scope.tmpFish.length?.value
				$scope.tmpFish.length =
					value: null
					unit: $scope.userUnits.length
			if !$scope.tmpFish.weight?.value
				$scope.tmpFish.weight =
					value: null
					unit: $scope.userUnits.weight
			$scope.editing = true
			$log.debug "Editing fish(#{index}): #{angular.toJson $scope.tmpFish}"
			$scope.fishEdit.show event
		$scope.$on 'popover.hidden', -> if $scope.editing
			$scope.editing = false
			$log.debug "Hide popover"
			if $scope.tmpFish?.name and $scope.tmpFish?.count
				if !$scope.tmpFish.length?.value
					$scope.tmpFish.length = undefined
				if !$scope.tmpFish.weight?.value
					$scope.tmpFish.weight = undefined
				$log.debug "Overrinding current fish"
				angular.copy $scope.tmpFish, $scope.current

.directive 'gist', ($log, $ionicLoading) ->
	restrict: 'E',
	replace: true,
	template: '<div></div>',
	link: ($scope, $element, $attrs) ->
		$ionicLoading.show()
		gistId = $attrs.id

		iframe = document.createElement 'iframe'
		iframe.setAttribute 'width', '100%'
		iframe.setAttribute 'height', '100%'
		iframe.setAttribute 'marginheight', 0
		iframe.setAttribute 'marginwidth', 0
		iframe.setAttribute 'frameborder', '0'
		iframe.id = "gist-#{gistId}"
		$element[0].appendChild(iframe)

		doc = 
			if iframe.contentDocument
				iframe.contentDocument
			else
				if iframe.contentWindow?.document
					iframe.contentWindow.document 
				else
					iframe.document
		doc.open()
		doc.write """
			<html>
			<head>
				<script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
				<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/gist-embed/2.1/gist-embed.min.js"></script>
			</head>
			<body>
				<code data-gist-id="#{gistId}" data-gist-hide-footer="true" data-gist-show-loading="false"></code>
			</body>
			</html>
		"""
		doc.close()
		$ionicLoading.hide()

.directive 'fathensFitImg', ($log, $ionicScrollDelegate) ->
	getProp = (obj, [h, ...left]:list) ->
		next = obj[h]
		if next && left.length > 0
		then getProp(next, left)
		else next

	restrict: 'E'
	template: '<ion-scroll><div><img/></div></ion-scroll>'
	replace: true
	link: ($scope, $element, $attrs) !->
		div = $element.children!.children![0]
		img = $element.children!.children!.children!
		photo = $attrs['src']
		if photo && photo.length > 0
			chain = photo.split('.')
			$scope.$watch chain[0], !->
				photo-url = getProp $scope, chain
				if photo-url
					$log.debug "fathensFitImg: img=#{img}, photo=#{photo}, src=#{photo-url}"
					img.attr('src', photo-url)
					img.on 'load', !->
						rect =
							width: img[0].clientWidth
							height: img[0].clientHeight
						max = if document.documentElement.clientWidth < document.documentElement.clientHeight then rect.width else rect.height
						div.style.width = "#{_.min max, rect.width}px"
						div.style.height = "#{_.min max, rect.height}px"
						$log.debug "fathensFitImg: #{angular.toJson rect} ==> #{max}"
						# Scroll to center
						margin = (f) -> if max < f(rect) then (f(rect) - max)/2 else 0
						delegate-name = $attrs['delegateHandle']
						sc =
							left: margin (.width)
							top: margin (.height)
						$ionicScrollDelegate.$getByHandle(delegate-name).scrollTo sc.left, sc.top
						$log.debug "fathensFitImg: scroll=#{angular.toJson sc}, name=#{delegate-name}"

.directive 'textareaElastic', ($log) ->
	restrict: 'E'
	template: '<textarea ng-keypress="elasticTextarea()"></textarea>'
	replace: true
	scope: true
	controller: ($scope, $element, $attrs) ->
		$scope.elasticTextarea = !->
			area = $element[0]
			current = area.style.height
			next = "#{area.scroll-height + 20}px"
			if current != next
				$log.debug "Elastic #{area}: #{current} => #{next}"
				area.style.height = next

.directive 'fathensEditReport', ($log) ->
	restrict: 'E'
	templateUrl: 'page/report/editor-report.html'
	replace: true
	controller: ($scope, $element, $attrs, $timeout, $state, $ionicPopover, ConditionFactory) ->
		$ionicPopover.fromTemplateUrl 'spot-location',
			scope: $scope
		.then (popover) !->
			$scope.spot-location = popover

		$ionicPopover.fromTemplateUrl 'choose-tide',
			scope: $scope
		.then (popover) !->
			$scope.choose-tide = popover

		$ionicPopover.fromTemplateUrl 'range-moon',
			scope: $scope
		.then (popover) !->
			$scope.range-moon = popover

		$scope.condition-modified = false
		$scope.condition-modify = !->
			$log.debug "Condition modified by user"
			$scope.condition-modified = true
		$scope.$watch 'report.tide', (new-value, old-value) !->
			$timeout !->
				$scope.choose-tide.hide!
			, 500
		$scope.$watch 'report.moon', (new-value, old-value) !->
			$timeout.cancel $scope.moon-changed
			$scope.moon-changed = $timeout !->
				$scope.range-moon.hide!
			, 500
		$scope.$watch 'report.dateAt', (new-value, old-value) !-> if !$scope.condition-modified
			ConditionFactory.state new-value, $scope.report.location.geoinfo, (state) !->
				$log.debug "Conditions result: #{angular.toJson state}"
				$scope.report?.moon = state.moon.age
				$scope.report?.tide = state.tide.state

		$scope.tide-icon = -> $scope.tide-phases |> _.find (.name == $scope.report.tide) |> (.icon)
		$scope.moon-icon = -> ConditionFactory.moon-phases[$scope.report.moon]

		$scope.tide-phases = ConditionFactory.tide-phases

		$scope.showMap = ($event) !->
			$scope.spot-location.show $event
			.then !->
				geoinfo = $scope.report.location.geoinfo
				div = document.getElementById "gmap"
				new google.maps.Map div,
					center: new google.maps.LatLng(geoinfo.latitude, geoinfo.longitude)
					zoom: 8
					mapTypeId: google.maps.MapTypeId.HYBRID
					disableDefaultUI: true
				google.maps.event.addDomListener div, 'click', !->
					$scope.spot-location.hide!
					$scope.use-current!
					$state.go "view-on-map",
						edit: true

.directive 'fathensEditFishes', ($log) ->
	restrict: 'E'
	templateUrl: 'page/report/editor-fishes.html'
	replace: true
	scope: true
	controller: ($scope, $element, $attrs, $timeout, $ionicPopover, UnitFactory) ->
		$scope.units = UnitFactory.units!
		$scope.user-units =
			length: 'cm'
			weight: 'kg'
		UnitFactory.load (units) !->
			$scope.user-units <<< units

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
		$scope.editing = false
		$scope.editFish = (event, index) !->
			$scope.current = $scope.report.fishes[index]
			$scope.tmpFish = angular.copy $scope.current
			$scope.editing = true
			$log.debug "Editing fish(#{index}): #{angular.toJson $scope.tmpFish}"
			$ionicPopover.fromTemplateUrl 'fish-edit',
				scope: $scope
			.then (popover) !->
				$scope.fish-edit = popover
				$scope.fish-edit.show event
				.then !->
					el = document.getElementById('fish-name')
					$log.debug "Focusing to #{el} at #{angular.toJson el.getBoundingClientRect!}"
					el.focus!
					$timeout !->
						window.scrollTo 0, el.getBoundingClientRect!.top - 20
					, 100
		$scope.$on 'popover.hidden', !-> if $scope.editing
			$scope.editing = false
			$log.debug "Hide popover"
			$scope.fish-edit.remove!
			if $scope.tmpFish?.name && $scope.tmpFish?.count
				$log.debug "Overrinding current fish"
				$scope.current <<< $scope.tmpFish

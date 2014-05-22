.controller 'MenuCtrl', ($log, $scope, PhotoFactory) !->

	$scope.openMap = !-> alert "Open Map"

.controller 'ShowRecordsCtrl', ($log, $scope, $ionicModal, $ionicPopup, RecordFactory) !->
	$ionicModal.fromTemplateUrl 'template/show-record.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-up'

	$scope.refreshRecords = !->
		$scope.records = RecordFactory.load!
	$scope.$on 'fathens-records-changed', (event, args) !->
		$scope.refreshRecords!

	$scope.detail = (index) !->
		$scope.index = index
		$scope.record = $scope.records[index]
		$scope.modal.show!

	$scope.delete = (index) !->
		$ionicPopup.confirm {
			title: "Delete Record"
			template: "Are you sure to delete this record ?"
		}
		.then (res) !-> if res
			RecordFactory.remove index
			$scope.$broadcast 'fathens-records-changed'
			$scope.modal.hide!

	$scope.close = !-> $scope.modal.hide!

.controller 'EditRecordCtrl', ($log, $scope, $rootScope, $ionicModal, RecordFactory) !->
	# $scope.record = 表示中のレコード
	# $scope.index = 表示中のレコードの index
	$ionicModal.fromTemplateUrl 'template/edit-record.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-up'

	$scope.title = "Edit Record"

	$scope.edit = !->
		$scope.currentRecord = angular.copy $scope.record
		$scope.modal.show!

	$scope.cancel = !->
		angular.copy $scope.currentRecord, $scope.record
		$scope.modal.hide!
	
	$scope.submit = !->
		$scope.currentRecord = null
		RecordFactory.update $scope.index, $scope.record
		$rootScope.$broadcast 'fathens-records-changed'
		$scope.modal.hide!

.controller 'AddRecordCtrl', ($log, $scope, $rootScope, $ionicModal, $ionicPopup, PhotoFactory, RecordFactory) !->
	$ionicModal.fromTemplateUrl 'template/edit-record.html'
		, (modal) !-> $scope.modal = modal
		,
			scope: $scope
			animation: 'slide-in-up'

	$scope.title = "New Record"

	newRecord = (uri) ->
		photo: uri
		dateAt: new Date!
		location:
			name: "Here"
			latLng: null
		fishes: []
		comment: ""


	$scope.open = !->
		$log.info "Opening modal..."
		PhotoFactory.select (uri) !->
			$scope.$apply $scope.record = newRecord uri
			$scope.modal.show!
		, (msg) !->
			$ionicPopup.alert {
				title: "No photo selected"
				subTitle: "Need a photo to record"
			}

	$scope.setLatLng = (latLng) !-> $scope.record.location.latLng = latLng

	$scope.cancel = !-> $scope.modal.hide!
	$scope.submit = !->
		RecordFactory.add $scope.record
		$rootScope.$broadcast 'fathens-records-changed'
		$scope.modal.hide!

.controller 'GMapCtrl', ($log, $scope) !->
	$scope.markar = null

	create-map = (setter) !->
		$scope.gmap = plugin.google.maps.Map.getMap {
			'mapType': plugin.google.maps.MapTypeId.HYBRID
			'controls':
				'myLocationButton': true
				'zoom': true
		}
		$scope.gmap.on plugin.google.maps.event.MAP_READY, (gmap) !-> gmap.showDialog!
		$scope.gmap.on plugin.google.maps.event.MAP_CLICK, (latLng) !->
			setter latLng
			$scope.markar?.remove!
			$scope.gmap.addMarker {
				'position': latLng
			}, (marker) !->
				$scope.$apply $scope.markar = marker

	$scope.showMap = (setter) !->
		if $scope.gmap
			$scope.gmap.showDialog!
		else
			create-map setter

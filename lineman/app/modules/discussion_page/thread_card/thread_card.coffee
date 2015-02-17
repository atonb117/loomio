angular.module('loomioApp').directive 'threadCard', ->
  scope: {discussion: '='}
  restrict: 'E'
  templateUrl: 'generated/modules/discussion_page/thread_card/thread_card.html'
  replace: true
  controller: ($scope, $rootScope, Records) ->
    nextPage = 1

    busy = false
    visibleItems = []

    $scope.lastPage = false

    setLastVisibleItem = ->
      $scope.lastVisibleItem = _.max visibleItems, (item) ->
        item.sequenceId
      console.log('last visible item:', $scope.lastVisibleItem.sequenceId, 'total items', )

    # push items into visibleItems when they become visible
    $scope.threadItemHidden = (item) ->
      _.remove visibleItems, item
      setLastVisibleItem()

    $scope.threadItemVisible = (item) ->
      visibleItems.push item
      setLastVisibleItem()

    $scope.getNextPage = ->
      return false if busy or $scope.lastPage
      busy = true
      Records.events.fetch(discussion_key: $scope.discussion.key, page: nextPage).then (data) ->
        events = data.events
        $scope.lastPage = true if events.length == 0
        nextPage = nextPage + 1
        busy = false

    $scope.getNextPage()

    $scope.safeEvent = (kind) ->
      _.contains ['new_comment', 'new_motion', 'new_vote'], kind

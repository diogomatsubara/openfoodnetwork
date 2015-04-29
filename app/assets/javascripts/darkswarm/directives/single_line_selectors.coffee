Darkswarm.directive 'singleLineSelectors', ($timeout, $filter) ->
  restrict: 'E'
  templateUrl: "single_line_selectors.html"
  scope:
    objects: "&"
    activeSelectors: "="
  link: (scope,element,attrs) ->
    scope.fitting = false

    scope.overFlowSelectors = ->
      return [] unless scope.allSelectors?
      $filter('filter')(scope.allSelectors, { fits: false })

    scope.selectedOverFlowSelectors = ->
      $filter('filter')(scope.overFlowSelectors(), { active: true })

    # had to duplicate this to make overflow selectors work
    scope.emit = ->
      scope.activeSelectors = scope.allSelectors.filter (selector)->
        selector.active
      .map (selector)->
        selector.object.id

    # From: http://stackoverflow.com/questions/4298612/jquery-how-to-call-resize-event-only-once-its-finished-resizing
    debouncer = (func, timeout) ->
      timeoutID = undefined
      timeout = timeout or 50
      ->
        subject = this
        args = arguments
        clearTimeout timeoutID
        timeoutID = setTimeout(->
          func.apply subject, Array::slice.call(args)
        , timeout)

    loadWidths = ->
      $(element).find("li").not(".more").each (i) ->
        scope.allSelectors[i].width = $(this).outerWidth(true)
        return null # So we don't exit the loop weirdly


    fit = ->
      used = $(element).find("li.more").outerWidth(true)
      used += selector.width for selector in scope.allSelectors when selector.fits
      available = $(element).parent(".filter-shopfront").innerWidth() - used
      if available > 0
        for selector in scope.allSelectors when !selector.fits
          available -= selector.width
          selector.fits = true if available > 0
      else
        if scope.allSelectors.length > 0
          for i in [scope.allSelectors.length-1..0]
            selector = scope.allSelectors[i]
            if !selector.fits
              continue
            else
              if available < 0
                selector.fits = false
                available += selector.width
      scope.fitting = false

    scope.$watchCollection "allSelectors", ->
      if scope.allSelectors?
        scope.fitting = true
        selector.fits = true for selector in scope.allSelectors
        $timeout(loadWidths, 0, true).then ->
          $timeout fit, 0, true

    $(window).resize debouncer (e) ->
      scope.fitting = true
      if scope.allSelectors?
        $timeout fit, 0, true
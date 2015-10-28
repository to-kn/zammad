class App.ControllerForm extends App.Controller
  constructor: (params) ->
    for key, value of params
      @[key] = value

    if !@handlers
      @handlers = []
    @handlers.push @showHideToggle
    @handlers.push @requiredMandantoryToggle

    # set empty class attributes if needed
    if !@form
      @form = @formGen()
    if !@model
      @model = {}
    if !@attributes
      @attributes = []

    # if element is given, prepend form to it
    if @el
      @el.prepend( @form )

    # trigger change to rebuild shown/hidden item and update sub selections
    if typeof @form is 'object'
      @form.find('input').trigger('change')
      @form.find('textarea').trigger('change')
      @form.find('select').trigger('change')

    @finishForm = true
    @form

  html: =>
    @form.html()

  formGen: ->
    App.Log.debug 'ControllerForm', 'formGen', @model.configure_attributes

    # check if own fieldset should be generated
    if @noFieldset
      fieldset = @el
    else
      fieldset = $('<fieldset></fieldset>')

    # collect form attributes
    @attributes = []
    if @model.attributesGet
      attributesClean = @model.attributesGet(@screen)
    else
      attributesClean = App.Model.attributesGet(@screen, @model.configure_attributes )

    for attributeName, attribute of attributesClean

      # ignore read only attributes
      if !attribute.readonly

        # check generic filter
        if @filter && !attribute.filter
          if @filter[ attributeName ]
            attribute.filter = @filter[ attributeName ]

        @attributes.push attribute

    attribute_count = 0
    className       = @model.className + '_' + Math.floor( Math.random() * 999999 ).toString()

    for attribute in @attributes
      attribute_count = attribute_count + 1

      # add item
      item = @formGenItem( attribute, className, fieldset, attribute_count )
      item.appendTo(fieldset)

      # if password, add confirm password item
      if attribute.type is 'password'

        # set selected value passed on current params
        if @params
          if attribute.name of @params
            attribute.value = @params[attribute.name]

        # rename display and name to _confirm
        if !attribute.single
          attribute.display = attribute.display + ' (confirm)'
          attribute.name = attribute.name + '_confirm'
          item = @formGenItem( attribute, className, fieldset, attribute_count )
          item.appendTo(fieldset)

    if @fullForm
      if !@formClass
        @formClass = ''
      fieldset = $('<form class="' + @formClass + '"><button class="btn">' + App.i18n.translateContent('Submit') + '</button></form>').prepend( fieldset )

    # bind form events
    if @events
      for eventSelector, callback of @events
        do (eventSelector, callback) ->
          evs = eventSelector.split(' ')
          fieldset.find( evs[1] ).bind( evs[0], (e) -> callback(e) )

    # return form
    return fieldset

  ###

  # input text field with max. 100 size
  attribute_config = {
    name:     'subject'
    display:  'Subject'
    tag:      'input'
    type:     'text'
    limit:    100
    null:     false
    default:  defaults['subject']
    class:    'span7'
  }

  # colection as relation with auto completion
  attribute_config = {
    name:           'customer_id'
    display:        'Customer'
    tag:            'autocompletion'
    # auto completion params, endpoints, ui,...
    type:           'text'
    limit:          100
    null:           false
    relation:       'User'
    autocapitalize: false
    help:           'Select the customer of the ticket or create one.'
    helpLink:       '<a href="" class="customer_new">&raquo;</a>'
    callback:       @userInfo
    class:          'span7'
  }

  # colection as relation
  attribute_config = {
    name:       'priority_id'
    display:    'Priority'
    tag:        'select'
    multiple:   false
    null:       false
    relation:   'TicketPriority'
    default:    defaults['priority_id']
    translate:  true
    class:      'medium'
  }


  # colection as options
  attribute_config = {
    name:       'priority_id'
    display:    'Priority'
    tag:        'select'
    multiple:   false
    null:       false
    options: [
      {
        value:    5
        name:     'very hight'
        selected: false
        disable:  false
      },
      {
        value:    3
        name:     'normal'
        selected: true
        disable:  false
      },
    ]
    default:    3
    translate:  true
    class:      'medium'
  }


  ###

  formGenItem: (attribute_config, classname, form, attribute_count ) ->
    attribute = clone( attribute_config, true )

    # create item id
    attribute.id = classname + '_' + attribute.name

    # set label class name
    attribute.label_class = @model.labelClass

    # set autofocus
    if @autofocus && attribute_count is 1
      attribute.autofocus = 'autofocus'

    # set required option
    if !attribute.null
      attribute.required = 'required'
    else
      attribute.required = ''

    # set autocapitalize option
    if attribute.autocapitalize is undefined || attribute.autocapitalize
      attribute.autocapitalize = ''
    else
      attribute.autocapitalize = 'autocapitalize="off"'

    # set autocomplete option
    if attribute.autocomplete is undefined
      attribute.autocomplete = ''
    else
      attribute.autocomplete = 'autocomplete="' + attribute.autocomplete + '"'

    # set default values
    if attribute.value is undefined && 'default' of attribute
      attribute.value = attribute.default

    # set params value
    if @params

      # check if we have a references
      parts = attribute.name.split '::'
      if parts[0] && parts[1]
        if @params[ parts[0] ] && @params[ parts[0] ][ parts[1] ]
          attribute.value = @params[ parts[0] ][ parts[1] ]

      # set params value to default
      if attribute.name of @params
        attribute.value = @params[attribute.name]

    App.Log.debug 'ControllerForm', 'formGenItem-before', attribute

    if App.UiElement[attribute.tag]
      item = App.UiElement[attribute.tag].render(attribute, @params, @)
    else
      throw "Invalid UiElement.#{attribute.tag}"

    if @handlers
      item.bind('change', (e) =>
        params = App.ControllerForm.params( $(e.target) )
        for handler in @handlers
          handler(params, attribute, @attributes, classname, form, @)
      )

    # bind dependency
    if @dependency
      for action in @dependency

        # bind on element if name is matching
        if action.bind && action.bind.name is attribute.name
          ui = @
          do (action, attribute) ->
            item.bind('change', ->
              value = $(@).val()
              if !value
                value = $(@).find('select, input').val()

              # lookup relation if needed
              if action.bind.relation
                data = App[action.bind.relation].find( value )
                value = data.name

              # check if value is used in condition
              if _.contains( action.bind.value, value )
                if action.change.action is 'hide'
                  ui.hide(action.change.name)
                else
                  ui.show(action.change.name)
            )

    if !attribute.display

      # hide/show item
      #if attribute.hide
      #  @.hide(attribute.name)

      return item
    else
      fullItem = $(
        App.view('generic/attribute')(
          attribute: attribute,
          item:      '',
          bookmarkable: @bookmarkable
        )
      )
      fullItem.find('.controls').prepend( item )

      # hide/show item
      if attribute.hide
        @.hide(attribute.name, fullItem)

      return fullItem

  show: (name, el = @el) ->
    if !_.isArray(name)
      name = [name]
    for key in name
      el.find('[name="' + key + '"]').closest('.form-group').removeClass('hide')
      el.find('[name="' + key + '"]').removeClass('is-hidden')
      el.find('[data-name="' + key + '"]').closest('.form-group').removeClass('hide')
      el.find('[data-name="' + key + '"]').removeClass('is-hidden')

    # hide old validation states
    if el
      el.find('.has-error').removeClass('has-error')
      el.find('.help-inline').html('')

  hide: (name, el = @el) ->
    if !_.isArray(name)
      name = [name]
    for key in name
      el.find('[name="' + key + '"]').closest('.form-group').addClass('hide')
      el.find('[name="' + key + '"]').addClass('is-hidden')
      el.find('[data-name="' + key + '"]').closest('.form-group').addClass('hide')
      el.find('[data-name="' + key + '"]').addClass('is-hidden')

  mandantory: (name, el = @el) ->
    if !_.isArray(name)
      name = [name]
    for key in name
      el.find('[name="' + key + '"]').attr('required', true)
      el.find('[name="' + key + '"]').parents('.form-group').find('label span').html('*')

  optional: (name, el = @el) ->
    if !_.isArray(name)
      name = [name]
    for key in name
      el.find('[name="' + key + '"]').attr('required', false)
      el.find('[name="' + key + '"]').parents('.form-group').find('label span').html('')

  showHideToggle: (params, changedAttribute, attributes, classname, form, ui) ->
    for attribute in attributes
      if attribute.shown_if
        hit = false
        for refAttribute, refValue of attribute.shown_if
          if params[refAttribute]
            if _.isArray( refValue )
              for item in refValue
                if params[refAttribute].toString() is item.toString()
                  hit = true
            else if params[refAttribute].toString() is refValue.toString()
              hit = true
        if hit
          ui.show(attribute.name)
        else
          ui.hide(attribute.name)

  requiredMandantoryToggle: (params, changedAttribute, attributes, classname, form, ui) ->
    for attribute in attributes
      if attribute.required_if
        hit = false
        for refAttribute, refValue of attribute.required_if
          if params[refAttribute]
            if _.isArray( refValue )
              for item in refValue
                if params[refAttribute].toString() is item.toString()
                  hit = true
            else if params[refAttribute].toString() is refValue.toString()
              hit = true
        if hit
          ui.mandantory(attribute.name)
        else
          ui.optional(attribute.name)

  validate: (params) ->
    App.Model.validate(
      model:  @model
      params: params
      screen: @screen
  )

  # get all params of the form
  @params: (form) ->
    param = {}

    lookupForm = @findForm(form)

    # get contenteditable
    for element in lookupForm.find('[contenteditable]')
      name = $(element).data('name')
      if name
        param[name] = $(element).ceg()

    # get form elements
    array = lookupForm.serializeArray()

    # array to names
    for key in array

      # check if item is-hidden and should not be used
      if lookupForm.find('[name="' + key.name + '"]').hasClass('is-hidden')
        param[key.name] = undefined
        continue

      # collect all params, push it to an array if already exists
      if param[key.name] isnt undefined
        if typeof param[key.name] is 'string'
          param[key.name] = [param[key.name], key.value.trim()]
        else
          param[key.name].push key.value.trim()
      else
        param[key.name] = key.value.trim()

    # data type conversion
    for key of param

      # get boolean
      if key.substr(0,9) is '{boolean}'
        newKey = key.substr(9, key.length)
        if param[key] && param[key].toString() is 'true'
          param[newKey] = true
        else
          param[newKey] = false
        delete param[key]

      # get {date}
      else if key.substr(0,6) is '{date}'
        newKey = key.substr(6, key.length)
        if lookupForm.find("[data-name=\"#{newKey}\"]").hasClass('is-hidden')
          param[newKey] = null
        else if param[key]
          try
            time = new Date( Date.parse( "#{param[key]}T00:00:00Z" ) )
            format = (number) ->
              if parseInt(number) < 10
                number = "0#{number}"
              number
            if time is 'Invalid Date'
              throw "Invalid Date #{param[key]}"
            param[newKey] = "#{time.getUTCFullYear()}-#{format(time.getUTCMonth()+1)}-#{format(time.getUTCDate())}"
          catch err
            param[newKey] = "invalid #{param[key]}"
            console.log('ERR', err)
        else
          param[newKey] = undefined
        delete param[key]

      # get {datetime}
      else if key.substr(0,10) is '{datetime}'
        newKey = key.substr(10, key.length)
        if lookupForm.find("[data-name=\"#{newKey}\"]").hasClass('is-hidden')
          param[newKey] = null
        else if param[key]
          try
            time = new Date( Date.parse( param[key] ) )
            if time is 'Invalid Datetime'
              throw "Invalid Datetime #{param[key]}"
            param[newKey] = time.toISOString().replace(/:\d\d\.\d\d\dZ$/, ':00.000Z')
          catch err
            param[newKey] = "invalid #{param[key]}"
            console.log('ERR', err)
        else
          param[newKey] = undefined
        delete param[key]

    # split :: fields, build objects
    inputSelectObject = {}
    for key of param
      parts = key.split '::'
      if parts[0] && parts[1]
        if !(parts[0] of inputSelectObject)
          inputSelectObject[ parts[0] ] = {}
        if !parts[2]
          inputSelectObject[ parts[0] ][ parts[1] ] = param[ key ]
        else
          if !(parts[1] of inputSelectObject[ parts[0] ])
            inputSelectObject[ parts[0] ][ parts[1] ] = {}
          inputSelectObject[ parts[0] ][ parts[1] ][ parts[2] ] = param[ key ]
        delete param[ key ]

    # set new object params
    for key of inputSelectObject
      param[ key ] = inputSelectObject[ key ]

    # data type conversion
    for key of param

      # get {business_hours}
      if key.substr(0,16) is '{business_hours}'
        newKey = key.substr(16, key.length)
        if lookupForm.find("[data-name=\"#{newKey}\"]").hasClass('is-hidden')
          param[newKey] = null
        else if param[key]
          newParams = {}
          for day, value of param[key]
            newParams[day] = {}
            newParams[day].active = false
            if value.active is 'true'
              newParams[day].active = true
            newParams[day].timeframes = []
            if _.isArray(value.start)
              for pos of value.start
                newParams[day].timeframes.push [ value.start[pos], value.end[pos] ]
            else
              newParams[day].timeframes.push [ value.start, value.end ]
          param[newKey] = newParams
        else
          param[newKey] = undefined
        delete param[key]

    #App.Log.notice 'ControllerForm', 'formParam', form, param
    param

  @formId: ->
    formId = new Date().getTime() + Math.floor( Math.random() * 99999 )
    formId.toString().substr formId.toString().length-9, 9

  @findForm: (form) ->
    # check jquery event
    if form && form.target
      form = form.target

    # create jquery object if not already exists
    if form instanceof jQuery
      # do nothing
    else
      form = $(form)

    #console.log('FF', form)
    # get form
    if form.is('form') is true
      #console.log('direct from')
      return form
    else if form.find('form').is('form') is true
      #console.log('child from')
      return form.find('form')
    else if $(form).closest('form').is('form') is true
      #console.log('closest from')
      return form.closest('form')
    # use current content as form if form isn't already finished
    else if !@finishForm
      #console.log('finishForm')
      return form
    else
      App.Log.error 'ControllerForm', 'no form found!', form
    form

  @disable: (form) ->
    lookupForm = @findForm(form)

    if lookupForm
      App.Log.debug 'ControllerForm', 'disable form...', lookupForm

      # set forms to read only during communication with backend
      lookupForm.find('button, input, select, textarea').attr('readonly', true)

      # disable additionals submits
      lookupForm.find('button.btn').attr('disabled', true)
    else
      App.Log.notice 'ControllerForm', 'disable item...', form
      form.attr('readonly', true)
      form.attr('disabled', true)

  @enable: (form) ->

    lookupForm = @findForm(form)

    if lookupForm
      App.Log.debug 'ControllerForm', 'enable form...', lookupForm

      # enable fields again
      lookupForm.find('button, input, select, textarea').attr('readonly', false)

      # enable submits again
      lookupForm.find('button.btn').attr('disabled', false)
    else
      App.Log.notice 'ControllerForm', 'enable item...', form
      form.attr('readonly', false)
      form.attr('disabled', false)

  @validate: (data) ->

    lookupForm = @findForm(data.form)

    # remove all errors
    lookupForm.find('.has-error').removeClass('has-error')
    lookupForm.find('.help-inline').html('')

    # show new errors
    for key, msg of data.errors

      # generic validation
      itemGeneric = lookupForm.find('[name="' + key + '"]').closest('.form-group')
      itemGeneric.addClass('has-error')
      itemGeneric.find('.help-inline').html(msg)

      # use meta fields
      itemMeta = lookupForm.find('[data-name="' + key + '"]').closest('.form-group')
      itemMeta.addClass('has-error')
      itemMeta.find('.help-inline').html(msg)

      # use native fields
      itemGeneric = lookupForm.find('[name="' + key + '"]').closest('.form-control')
      itemGeneric.trigger('validate')
      itemMeta = lookupForm.find('[data-name="' + key + '"]').closest('.form-control')
      itemMeta.trigger('validate')

    # set autofocus by delay to make validation testable
    App.Delay.set(
      ->
        lookupForm.find('.has-error').find('input, textarea, select').first().focus()
      200
      'validate'
    )
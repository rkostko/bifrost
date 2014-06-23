###
 * jQuery Bifröst v1.0.0.alpha
 * http://matiasgagliano.github.com/bifrost/
 *
 * Copyright 2014, Matías Gagliano.
 * Dual licensed under the MIT or GPLv3 licenses.
 * http://opensource.org/licenses/MIT
 * http://opensource.org/licenses/GPL-3.0
 *
###
"use strict"

# ______________________________
#
#              Vars
# ______________________________
#
$ = jQuery
console = window.console || { log: -> }
iframeId = 0



# ______________________________
#
#          The Bifröst
# ______________________________
#
class Bifrost
  constructor: (@options, @originalOptions, @jqXHR) ->


  send: (headers, completeCallback) ->
    options = @options
    meta = {'X-Requested-With': 'IFrame'}
    meta['X-HTTP-Accept'] = options.accepts if options.accepts?

    # RESTful API
    if options.type in ['DELETE', 'PUT', 'PATCH']
      meta['_method'] = options.type
      options.type = 'POST'

    # Iframe
    iframeId++
    iframeName = "iframe-transport-#{iframeId}"
    iframe = @iframe = $('<iframe>').css('display', 'none')
    iframe.attr name: iframeName, src: 'javascript:false;'
      # 'javascript:false;' as initial src prevents warning popups on HTTPS in IE6
    iframe.appendTo document.body
    iframe.one 'load', ->
      # Catch exceptions thrown when trying to access cross-domain iframe contents.
      # completeCallback(status, statusText, responses, headers)
      try
        response = iframe.contents().find('body').text()
        completeCallback 200, 'success', iframe: response
      catch error
        console.log error
        completeCallback 403, 'error', iframe: ''

      # Clean up
      form.remove()
      iframe.remove()

    # Form
    form = @form = $('<form>').css('display', 'none')
    form.prop target: iframeName, action: options.url, method: options.type
    form.appendTo document.body

    # Process data
    data = @originalOptions.data
    if $.isArray(data)  # Serialized as Array
      o = {}
      for pair in data
        [name, value] = [pair.name, pair.value]
        if o[name] is undefined    then o[name] = value
        else if $.isArray(o[name]) then o[name].push value  # For checkboxes
        else o[name] = [ o[name], value ]
      data = o
    data = $.extend {}, meta, data

    # Text inputs
    for name,value of data
      form.append $('<input>').attr(type: 'hidden', name: name, value: value)

    # File inputs
    fileInputs = $(options.fileInputs)
    clones = $()
    if options.type is 'POST' and fileInputs.length
      form.prop enctype: 'multipart/form-data', encoding: 'multipart/form-data'
      # Leave clones as markers
      clones = fileInputs.clone().prop('disabled', true)
      fileInputs.after (index) -> clones[index]
      # Move original file inputs to the hidden form
      form.append fileInputs

    # Submit
    form.submit()

    # Restore file inputs
    $(clone).replaceWith(fileInputs[i]) for clone,i in clones


  abort: ->
    @form.remove() if @form
    @iframe.off('load') if @iframe



# ______________________________
#
#        jQuery Transport
# ______________________________
#
# Bind transport
$.ajaxTransport 'iframe', (options, originalOptions, jqXHR) ->
  new Bifrost(options, originalOptions, jqXHR) if options.async

# Set convertes
# (The keys format is 'source_type destination_type', single space in-between)
$.ajaxSetup converters:
  'iframe text':   true
  'iframe json':   $.parseJSON
  'iframe html':   true
  'iframe xml':    $.parseXML
  'iframe script': $.globalEval

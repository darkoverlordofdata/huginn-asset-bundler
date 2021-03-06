#+--------------------------------------------------------------------+
#| bundle.coffee
#+--------------------------------------------------------------------+
#| Copyright DarkOverlordOfData (c) 2013
#+--------------------------------------------------------------------+
#|
#| This file is a part of Huginn
#|
#| Huginn is free software; you can copy, modify, and distribute
#| it under the terms of the MIT License
#|
#+--------------------------------------------------------------------+
#
# asset bundler huginn-plugin
#

fs = require('fs')
path = require('path')
yaml = require('yaml-js')
crypto = require('crypto')
jsmin = require('jsmin').jsmin
cssmin = require('cssmin')
Liquid = require('huginn-liquid')

#
# Connect to the site
# cache the configuration values
#
module.exports = (site) ->

  _js       = site.asset_bundler.markup_templates.js
  _css      = site.asset_bundler.markup_templates.css
  _cdn      = site.asset_bundler.server_url
  _url      = site.asset_bundler.base_path
  _prj      = site.asset_bundler.shim
  _dev      = site.asset_bundler.dev
  _src      = site.source
  _dst      = site.destination
  _min_js   = site.asset_bundler.compress.js
  _min_css  = site.asset_bundler.compress.css
  _err      = site.show_errors

  class Bundle extends Liquid.Block

    constructor: ($name, $markup, $tokens) ->
      super $name, $markup, $tokens

    render: ($ctx) ->
      $assets = super($ctx)

      if 'string' is typeof $assets
        @build $assets
      else
        @build $assets[0] # backwards compatible huginn-liquid < 0.0.7

    #
    # build the tag content
    #
    build: ($assets) ->


      $bundle = yaml.load($assets)
      if _dev # Just create tags for each asset file

        $s = ''
        for $asset in $bundle
          if /.js$/.test $asset
            $url = $asset.replace(/^\/_assets\//, _url)
            $s += _copy_asset $asset, $url
            $s += _js.replace("{{url}}", _prj+$url)

          else if /.css$/.test $asset
            $url = $asset.replace(/^\/_assets\//, _url)
            $s += _copy_asset $asset, $url
            $s += _css.replace("{{url}}", _prj+$url)

        $assets = $s

      else

        $js = ''
        $css = ''
        for $asset in $bundle
          $code = site.render(_src+$asset)
          if /.js$/.test $asset
            $js +=  if _min_js then jsmin($code, 3) else $code

          else if /.css$/.test $asset
            $css +=  if _min_css then cssmin($code) else $code

        $s = ''
        if $js.length
          $url_js = "assets/#{_md5($js)}.js"
          $s += _create_asset($url_js, $js)
          $s += _js.replace("{{url}}", "#{_prj}/#{$url_js}")

        if $css.length
          $url_css = "assets/#{_md5($css)}.css"
          $s += _create_asset($url_css, $css)
          $s += _css.replace("{{url}}", "#{_prj}/#{$url_css}")

        $assets = $s

      return $assets


    #
    # Create an asset
    #
    # @param  [String]  url   asset destination
    # @param  [String]  content
    # @return none
    #
    _create_asset = ($url, $content) ->

      try
        fs.writeFileSync "#{_dst}/#{$url}", $content
        ''
      catch $e
        console.log $e
        if _err then String($e) else ''

    #
    # Copy an asset
    #
    # @param  [String]  from  source asset
    # @param  [String]  to    destination asset
    # @return none
    #
    _copy_asset = ($from, $to) ->
      $src = path.resolve("#{_src}/#{$from}")
      $dst = path.resolve("#{_dst}/#{$to}")

      try
        fs.writeFileSync $dst, site.render($src)
        ''
      catch $e
        console.log $e
        if _err then String($e) else ''

    #
    # Compute an MD5 hash
    #
    # @param  [String]  str   string to hash
    # @param  [String]  encoding  output type = bin|hex|base64
    # @return none
    #
    _md5 = ($str, $encoding='hex') ->
      crypto.createHash('md5').update($str).digest($encoding)

  Liquid.Template.registerTag "bundle", Bundle


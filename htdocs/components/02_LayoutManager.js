// $Revision$

Ensembl.LayoutManager = new Base();

Ensembl.LayoutManager.extend({
  constructor: null,
  
  /**
   * Creates events on elements outside of the domain of panels
   */
  initialize: function () {
    this.id = 'LayoutManager';
    
    Ensembl.EventManager.register('reloadPage',    this, this.reloadPage);
    Ensembl.EventManager.register('validateForms', this, this.validateForms);
    Ensembl.EventManager.register('makeZMenu',     this, this.makeZMenu);
    Ensembl.EventManager.register('relocateTools', this, this.relocateTools);
    Ensembl.EventManager.register('hashChange',    this, this.hashChange);
    Ensembl.EventManager.register('toggleContent', this, this.toggleContent);
    Ensembl.EventManager.register('changeWidth',   this, this.changeWidth);
        
    $('#page_nav .tool_buttons > p').show();
    
    $('#header a:not(#tabs a)').addClass('constant');
    
    if ((window.location.hash.replace(/^#/, '?') + ';').match(Ensembl.locationMatch)) {
      $('.ajax_load').val(function (i, val) {
        return Ensembl.urlFromHash(val);
      });
      
      this.hashChange(Ensembl.urlFromHash(window.location.href, true));
    }
    
    $(document).on('click', '.modal_link', function () {
      if (Ensembl.EventManager.trigger('modalOpen', this)) {
        return false;
      }
    }).on('click', '.popup', function () {
      if (window.name.match(/^popup_/)) {
        return true;
      }
      
      window.open(this.href, 'popup_' + window.name, 'width=950,height=500,resizable,scrollbars');
      return false;
    }).on('click', 'a[rel="external"]', function () { 
      this.target = '_blank';
    });
    
    $('.modal_link').show();
    
    this.validateForms(document);
    
    // Close modal window if the escape key is pressed
    $(document).on({
      keyup: function (event) {
        if (event.keyCode === 27) {
          Ensembl.EventManager.trigger('modalClose', true);
        }
      },
      mouseup: function (e) {
        // only fired on left click
        if (!e.which || e.which === 1) {
          Ensembl.EventManager.trigger('mouseUp', e);
        }
      }
    });
    
    function popState() {
      Ensembl.setCoreParams();
      Ensembl.EventManager.trigger('hashChange', Ensembl.urlFromHash(window.location.href, true));
    }
    
    this.window = $(window).on({
      resize: function () {
        // jquery ui 1.8.14 causes window.resize to fire on resizable when using jquery 1.6.2
        // This is a hack to stop the windowResize event being triggered in that situation, until the bug is fixed
        // See http://bugs.jqueryui.com/ticket/7514
        var windowWidth  = Ensembl.LayoutManager.window.width();
        var windowHeight = Ensembl.LayoutManager.window.height();
        var width        = Ensembl.width;
        
        if (windowWidth !== Ensembl.LayoutManager.windowWidth || windowHeight !== Ensembl.LayoutManager.windowHeight) {
          Ensembl.setWidth(undefined, Ensembl.dynamicWidth);
          
          Ensembl.EventManager.trigger('windowResize');
          
          if (Ensembl.dynamicWidth && Ensembl.width !== width) {
            $('.navbar, div.info, div.hint, div.warning, div.error').width(Ensembl.width);
            Ensembl.EventManager.trigger('imageResize');
          }
        }
        
        Ensembl.LayoutManager.windowWidth  = windowWidth;
        Ensembl.LayoutManager.windowHeight = windowHeight;
      },
      hashchange: function (e) {
        if ((window.location.hash.replace(/^#/, '?') + ';').match(Ensembl.locationMatch) || !window.location.hash && Ensembl.hash.match(Ensembl.locationMatch)) {
          popState();
        }
      }
    });
    
    window.onpopstate = popState;
    
    var userMessage = unescape(Ensembl.cookie.get('user_message'));
    
    if (userMessage) {
      userMessage = userMessage.split('\n');
      
      $([
        '<div class="hint" style="margin: 10px 25%;">',
        ' <h3><img src="/i/close.gif" alt="Hide hint panel" title="Hide hint panel" />', userMessage[0], '</h3>',
        ' <p>', userMessage[1], '</p>',
        '</div>'
      ].join('')).prependTo('#main').find('h3 img, a').on('click', function () {
        $(this).parents('div.hint').remove();
        Ensembl.cookie.set('user_message', '');
      });
    }
  },
  
  reloadPage: function (args, url) {
    if (typeof args === 'string') {
      Ensembl.EventManager.triggerSpecific('updatePanel', args);
    } else if (typeof args === 'object') {
      for (var i in args) {
        Ensembl.EventManager.triggerSpecific('updatePanel', i);
      }
    } else {
      return Ensembl.redirect(url);
    }
    
    $('#messages').hide();
  },
  
  validateForms: function (context) {
    $('form.check', context).validate().on('submit', function () {
      var form = $(this);
      
      if (form.parents('#modal_panel').length) {
        var panels = form.parents('.js_panel').map(function () { return this.id; }).toArray();
        var rtn;
        
        while (panels.length && typeof rtn === 'undefined') {
          rtn = Ensembl.EventManager.triggerSpecific('modalFormSubmit', panels.shift(), form);
        }
        
        return rtn;
      }
    });
  },
  
  makeZMenu: function (id, params) {
    if (!$('#' + id).length) {
      $([
        '<div class="info_popup floating_popup" id="', id, '">',
        ' <span class="close"></span>',
        '  <table class="zmenu" cellspacing="0">',
        '    <thead>', 
        '      <tr class="header"><th class="caption" colspan="2"><span class="title"></span></th></tr>',
        '    </thead>', 
        '    <tbody class="loading">',
        '      <tr><td><p class="spinner"></p></td></tr>',
        '    </tbody>',
        '    <tbody></tbody>',
        '  </table>',
        '</div>'
      ].join('')).draggable({ handle: 'thead' }).appendTo('body');
    }
    
    Ensembl.EventManager.trigger('addPanel', id, 'ZMenu', undefined, undefined, params, 'showExistingZMenu');
  },
  
  relocateTools: function (tools) {
    var toolButtons = $('#page_nav .tool_buttons');
    
    tools.each(function () {
      var a        = $(this).find('a');
      var existing = $('.additional .' + a[0].className.replace(' ', '.'), toolButtons);
      
      if (existing.length) {
        existing.replaceWith(a);
      } else {
        $(this).children().addClass('additional').appendTo(toolButtons).not('.hidden').show();
      }
      
      a = existing = null;
    }).remove();
    
    $('a.seq_blast', toolButtons).on('click', function () {
      $('form.seq_blast', toolButtons).submit();
      return false;
    });
  },
  
  hashChange: function (r) {
    if (!r) {
      return;
    }
    
    var text = r.split(/\W/);
        text = text[0] + ': ' + Ensembl.thousandify(text[1]) + '-' + Ensembl.thousandify(text[2]);
    
    $('a:not(.constant)').attr('href', function () {
      var r;
      
      if (this.title === 'UCSC') {
        this.href = this.href.replace(/(&?position=)[^&]+(.?)/, '$1chr' + Ensembl.urlFromHash(this.href, true) + '$2');
      } else if (this.title === 'NCBI') {
        r = Ensembl.urlFromHash(this.href, true).split(/[:\-]/);
        this.href = this.href.replace(/(&?CHR=).+&BEG=.+&END=[^&]+(.?)/, '$1' + r[0] + '&BEG=' + r[1] + '&END=' + r[2] + '$2');
      } else {
        return Ensembl.urlFromHash(this.href);
      }
    });
    
    $('input[name=r]', 'form:not(#core_params)').val(r);
    
    $('h1.summary-heading').html(function (i, html) {
      return html.replace(/^(Chromosome ).+/, '$1' + text);
    });
    
    document.title = document.title.replace(/(Chromosome ).+/, '$1' + text);
  },
  
  toggleContent: function (rel) {
    if (rel) {
      $('a.toggle[rel="' + rel + '"]').toggleClass('open closed');
    }
  },
  
  changeWidth: function () {
    $('.navbar, div.info, div.hint, div.warning, div.error').width(Ensembl.width);
  }
});


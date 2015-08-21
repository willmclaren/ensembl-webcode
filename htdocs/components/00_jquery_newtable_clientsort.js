/*
 * Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *      http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

(function($) {
  $.fn.newtable_sort_numeric = function(a,b,c) {
    a = parseFloat(a);
    b = parseFloat(b);
    if(isNaN(a) || a === ' ' || a === '') {
      if(isNaN(b) || b === ' ' || b === '') {
        return $.fn.newtable_sort_string(''+a,''+b,c);
      } else {
        return 1;
      }
    } else if(isNaN(b) || b === ' ' || b === '') {
      return -1;
    } else {
      return (a-b)*c;
    }
  }

  $.fn.newtable_sort_string = function(a,b,c) {
    return a.toLowerCase().localeCompare(b.toLowerCase())*c;
  }

  $.fn.new_table_clientsort = function(config,data) {
    var col_idxs = {};
    $.each(config.columns,function(i,val) { col_idxs[val.key] = i; });

    function compare(a,b,plan) {
      var c = 0;
      $.each(plan,function(i,stage) {
        if(!c) {
          var av = a[stage[0]];
          var bv = b[stage[0]];
          c = av[1]-bv[1];
          if(!c) { c = stage[2](av[0],bv[0],stage[1]); }
        }
      });
      return c;
    }

    function build_plan(orient) {
      var plan  = [];
      var incr_ok = true;
      $.each(orient.sort,function(i,stage) {
        if(!plan) { return; }
        if(!data[stage.key]) { plan = null; return; }
        var type = $.fn['newtable_sort_'+data[stage.key].fn];
        if(!type) { plan = null; return; }
        plan.push([col_idxs[stage.key],stage.dir,type]);
        if(!data[stage.key].incr_ok) { incr_ok = false; }
      });
      if(!plan) { return null; }
      plan.push([config.columns.length,1,$.fn.newtable_sort_numeric]);
      return { stages: plan, incr_ok: incr_ok};
    }

    function mere_reversal(orient,target) {
      if(!orient.sort || !target.sort) { return null; }
      if(orient.sort.length>1 || target.sort.length>1) { return null; }
      if(orient.sort[0].key != target.sort[0].key) { return null; }
      if(orient.sort[0].dir != -target.sort[0].dir) { return null; }
      var idx = col_idxs[target.sort[0].key];
      orient.sort[0].dir *= -1;
      return function(manifest,grid) {
        var fabric = grid.slice();
        var partitioned = [[],[]];
        $.each(grid,function(i,row) {
          partitioned[row[idx][1]].push(row);
        });
        partitioned[0].reverse();
        partitioned[1].reverse();
        manifest.sort[0].dir *= -1;
        return [manifest,partitioned[0].concat(partitioned[1])];
      }
    }

    return {
      generate: function() {},
      go: function($table,$el) {},
      pipe: function() {
        return [
          function(need,got,wire) {
            var rev = mere_reversal(need,got);
            if(rev) { return { undo: rev }; }
            if(!need.sort) { return null; } // TODO can do more?
            var plan = build_plan(need);
            if(!plan) { return null; }
            wire.sort = need.sort;
            need.sort = got.sort;
            return {
              undo: function(manifest,grid) {
                var fabric = grid.slice();
                $.each(fabric,function(i,val) { val.push(i); }); // ties
                fabric.sort(function(a,b) {
                  return compare(a,b,plan.stages);
                });
                manifest.sort = wire.sort;
                return [manifest,fabric];
              },
              no_incr: !plan.incr_ok
            }
          }
        ];
      }
    };
  }; 

})(jQuery);
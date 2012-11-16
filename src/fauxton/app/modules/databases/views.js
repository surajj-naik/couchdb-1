define([
  "app",

  // Libs
  "backbone"

  // Plugins
],

function(app, Backbone) {
  var Views = {};

  Views.Item = Backbone.View.extend({
    template: "databases/item",
    tagName: "tr",

    serialize: function() {
      return {
        database: this.model
      };
    }
  });

  Views.List = Backbone.View.extend({
    template: "databases/list",
    events: {
      "click button.all": "selectAll"
    },

    initialize: function(options) {
      this.collection.on("add", this.render, this);
    },

    serialize: function() {
      return {
        databases: this.collection
      };
    },

    beforeRender: function() {
      this.collection.each(function(database) {
        this.insertView("table.databases tbody", new Views.Item({
          model: database
        }));
      }, this);
    },

    selectAll: function(evt){
      $("input:checkbox").attr('checked', !$(evt.target).hasClass('active'));
    }
  });

  Views.Sidebar = Backbone.View.extend({
    template: "databases/sidebar",
    events: {
      "click a#new": "newDatabase",
      "click a#owned": "showMine",
      "click a#shared": "showShared"
    },

    newDatabase: function() {
      // TODO: use a modal here instead of the prompt
      var name = prompt('Name of database', 'newdatabase');
      var db = new this.collection.model({
        id: encodeURIComponent(name),
        name: name
      });
      db.save();
      this.collection.add(db);
      // FIXME: The render that is triggered here fails to get status
      console.log("The render that is triggered here fails to get status");
    },

    showMine: function(){
      console.log('will show users databases and hide shared');
    },

    showShared: function(){
      console.log('will show shared databases and hide the users');
      alert('Support for shared databases coming soon');
    }
  });

  return Views;
});

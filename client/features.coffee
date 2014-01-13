# Define Minimongo collections to match server/publish.js.
Projects = new Meteor.Collection("projects")
Features = new Meteor.Collection("features")

# ID of currently selected project
Session.setDefault "project_id", null

# When editing a project name, ID of the project
Session.setDefault "editing_projectname", null

# When editing feature text, ID of the feature
Session.setDefault "editing_itemname", null

# Subscribe to 'projects' collection on startup.
# Select a project once data has arrived.
projectsHandle = Meteor.subscribe("projects", ->
  unless Session.get("project_id")
    project = Projects.findOne({}, sort: name: 1)
    Router.setProject project._id  if project
)
featuresHandle = null

# Always be subscribed to the features for the selected project.
Deps.autorun ->
  project_id = Session.get("project_id")
  if project_id
    featuresHandle = Meteor.subscribe("features", project_id)
  else
    featuresHandle = null

####### Helpers for in-place editing #######

# Returns an event map that handles the "escape" and "return" keys and
# "blur" events on a text input (given by selector) and interprets them
# as "ok" or "cancel".
okCancelEvents = (selector, callbacks) ->
  ok = callbacks.ok or ->

  cancel = callbacks.cancel or ->

  events = {}
  events["keyup " + selector + ", keydown " + selector + ", focusout " + selector] = (evt) ->
    if evt.type is "keydown" and evt.which is 27

      # escape = cancel
      cancel.call this, evt
    else if evt.type is "keyup" and evt.which is 13 or evt.type is "focusout"

      # blur/return/enter = ok/submit if non-empty
      value = String(evt.target.value or "")
      if value
        ok.call this, value, evt
      else
        cancel.call this, evt

  events

activateInput = (input) ->
  input.focus()
  input.select()

###### Projects ######
Template.projects.loading = ->
  not projectsHandle.ready()

Template.projects.projects = ->
  Projects.find({}, sort: name: 1)

Template.projects.features = (_id) =>
  features = Features.find(project_id: _id)
  features

Template.projects.events
  "mousedown .project": (evt) -> # select project
    Router.setProject @_id

  "click .project": (evt) ->
    # prevent clicks on <a> from refreshing the page.
    evt.preventDefault()

  "dblclick .project": (evt, tmpl) -> # start editing project name
    Session.set "editing_projectname", @_id
    Deps.flush() # force DOM redraw, so we can focus the edit field
    activateInput tmpl.find("#project-name-input")

# Attach events to keydown, keyup, and blur on "New project" input box.
Template.projects.events okCancelEvents("#new-project",
  ok: (text, evt) ->
    id = Projects.insert(name: text)
    Router.setProject id
    evt.target.value = ""
)
Template.projects.events okCancelEvents("#project-name-input",
  ok: (value) ->
    Projects.update @_id,
      $set:
        name: value

    Session.set "editing_projectname", null

  cancel: ->
    Session.set "editing_projectname", null
)
Template.projects.selected = ->
  (if Session.equals("project_id", @_id) then "selected" else "")

Template.projects.name_class = ->
  (if @name then "" else "empty")

Template.projects.editing = ->
  Session.equals "editing_projectname", @_id

######### Features ########

Template.features.loading = ->
  featuresHandle and not featuresHandle.ready()

Template.features.any_project_selected = ->
  not Session.equals("project_id", null)

Template.features.events okCancelEvents("#new-feature",
  ok: (text, evt) ->
    tag = Session.get("tag_filter")
    Features.insert
      title: text
      project_id: Session.get("project_id")
      active: false
      timestamp: (new Date()).getTime()
      tags: (if tag then [tag] else [])
    evt.target.value = ""
)

Template.features.features = ->
  # Determine which features to display in main pane,
  # selected based on project_id and tag_filter.
  project_id = Session.get("project_id")
  return {}  unless project_id
  sel = project_id: project_id
  tag_filter = Session.get("tag_filter")
  sel.tags = tag_filter  if tag_filter
  Features.find(sel, sort: timestamp: 1)

Template.feature_item.tag_objs = ->
  feature_id = @_id
  _.map @tags or [], (tag) ->
    feature_id: feature_id
    tag: tag


Template.feature_item.active_class = ->
  (if @active then "active" else "")

Template.feature_item.active_checkbox = ->
  (if @active then "checked=\"checked\"" else "")

Template.feature_item.editing = ->
  Session.equals "editing_itemname", @_id

Template.feature_item.adding_tag = ->
  Session.equals "editing_addtag", @_id

Template.feature_item.events
  "click": ->
    Session.set("selected_feature", this._id);

  "click .check": ->
    Features.update @_id,
      $set:
        active: not @active

  "click .destroy": ->
    Features.remove @_id

  "click .addtag": (evt, tmpl) ->
    Session.set "editing_addtag", @_id
    Deps.flush() # update DOM before focus
    activateInput tmpl.find("#edittag-input")

  "dblclick .display .feature-title": (evt, tmpl) ->
    Session.set "editing_itemname", @_id
    Deps.flush() # update DOM before focus
    activateInput tmpl.find("#feature-input")

  "click .remove": (evt) ->
    tag = @tag
    id = @feature_id
    evt.target.parentNode.style.opacity = 0

    # wait for CSS animation to finish
    Meteor.setTimeout (->
      Features.update
        _id: id
      ,
        $pull:
          tags: tag

    ), 300

Template.feature_item.events okCancelEvents("#feature-input",
  ok: (value) ->
    Features.update @_id,
      $set:
        title: value

    Session.set "editing_itemname", null

  cancel: ->
    Session.set "editing_itemname", null
)
Template.feature_item.events okCancelEvents("#edittag-input",
  ok: (value) ->
    Features.update @_id,
      $addToSet:
        tags: value

    Session.set "editing_addtag", null

  cancel: ->
    Session.set "editing_addtag", null
)

######### Details ###########
Template.details.any_feature_selected = ->
  not Session.equals("selected_feature", null)

Template.details.feature = ->
  Features.findOne Session.get('selected_feature')

#//////// Tracking selected project in URL //////////
FeaturesRouter = Backbone.Router.extend(
  routes:
    ":project_id": "main"

  main: (project_id) ->
    oldList = Session.get("project_id")
    if oldList isnt project_id
      Session.set "project_id", project_id
      Session.set "tag_filter", null

  setProject: (project_id) ->
    @navigate project_id, true
)
Router = new FeaturesRouter
Meteor.startup ->
  Backbone.history.start pushState: true


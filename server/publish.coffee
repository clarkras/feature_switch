# Projects -- {name: String}
Projects = new Meteor.Collection("projects")

# Publish complete set of lists to all clients.
Meteor.publish "projects", ->
  Projects.find()

# Features -- {title: String,
#             active: Boolean,
#             project_id: String,
#             timestamp: Number}
Features = new Meteor.Collection("features")

# Publish all items for requested project_id.
Meteor.publish "features", (project_id) ->
  check project_id, String
  Features.find project_id: project_id

share.Projects = Projects
share.Features = Features

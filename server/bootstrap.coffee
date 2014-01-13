# if the database is empty on server start, create some sample data.
Meteor.startup ->
  Projects = share.Projects
  Features = share.Features
  if Projects.find().count() is 0
    data = [
      name: "Social Campaigns"
      features: [
        ["Email Reporting", false]
        ["Social Promote (Facebookj", false]
        ["Social Promote (Twitter)", true]
      ]
    ]

    timestamp = (new Date()).getTime()
    for project in data
      project_id = Projects.insert(name: project.name)
      for info in project.features
        Features.insert
          project_id: project_id
          title: info[0]
          timestamp: timestamp
          active: info[1]
        timestamp += 1 # ensure unique timestamp.
  null


require 'active_record'

namespace :redmine do
  desc 'import from jira'
  task :jira => :environment do

    begin
      ActiveRecord::Base.connection.execute('ALTER TABLE `attachments` ADD `jira_id` INT NULL , ADD INDEX `jira_id` (`jira_id`);')
    rescue Exception => e
      puts e.message

    end
    begin
      ActiveRecord::Base.connection.execute('ALTER TABLE `issues` ADD `jira_id` INT NULL, ADD INDEX `jira_id` (`jira_id`);')
    rescue Exception => e
      puts e.message

    end
    begin
      ActiveRecord::Base.connection.execute('ALTER TABLE `time_entries` ADD `jira_id` INT NULL , ADD INDEX `jira_id` (`jira_id`);')
    rescue  Exception => e
      puts e.message

    end

# Add tracker




    f = File.open("jira/entities.xml")
    @doc = Nokogiri::XML f

    # IMPORT PROJECTS
    projects=@doc.xpath("//entity-engine-xml//Project")
    puts "Importing projects"
    projectMap={}
    projects.each { |jiraProject|

      if jiraProject.first_element_child()
        descr=jiraProject.first_element_child().content
      else
        descr=""
      end
      project = Project.create({:name => jiraProject["name"], :is_public => 1, :homepage => "", :status => 1,
                                :description => descr,
                                :identifier => jiraProject["key"].downcase
                               });

      puts project.errors.full_messages
      if project.errors.full_messages
        project=Project.find_by(identifier: jiraProject["key"].downcase)
      end

      projectMap[jiraProject["id"]]=project;

    }
    #IMPORT USERS
    puts "Importing user"
    users=@doc.xpath('//entity-engine-xml//User')
    usersMap={};
    users.each { |jiraUser|
      puts(jiraUser['lowerUserName']+' '+jiraUser['emailAddress'])
      puts(jiraUser['lowerEmailAddress'])
      puts(jiraUser)
      if !jiraUser['firstName'] || (jiraUser['firstName']=='')
        jiraUser['firstName']='-'
      end
      if jiraUser['lowerUserName']=='lena'
        jiraUser['emailAddress']='lena@kultprosvet.net'
      end
      user = User.new({
                          :login => jiraUser['lowerUserName'],
                          :firstname => jiraUser['firstName'],
                          :lastname => jiraUser['lastName'],
                          :mail => jiraUser['emailAddress'],
                          :status => jiraUser['active']
                      });
      user.login=jiraUser['lowerUserName']
      user.save


      if !user.errors.empty?
        puts user.errors.full_messages
      end

      usersMap[jiraUser['lowerUserName']]=User.find_by(login: jiraUser['lowerUserName'])

    }

    usersMap['alexandr']=User.find_by(login: 'semenag01')

    #IMPORT ISSUES
    puts 'Get issues links'
    links=@doc.xpath('//entity-engine-xml//IssueLink')
    issuesLinks={}
    links.each { |jiraIssueLink|
      if jiraIssueLink['linktype']=='10100'
        issuesLinks[jiraIssueLink['destination']]=jiraIssueLink['source']
      end

    }


    puts "Importing issues"
    trackers={
        '1' => 1,
        '3' => 3,
    }
    trackers.default=2;

    STATUS_MAP={
        '1' => IssueStatus.find_by(id: 1), #Open
        '2' => IssueStatus.find_by(id: 1), #Open
        '3' => IssueStatus.find_by(id: 2), # In progress
        '4' => IssueStatus.find_by(id: 3), # resolved
        '5' => IssueStatus.find_by(id: 4), # reopened
        '6' => IssueStatus.find_by(id: 5) # closed
    }
    STATUS_MAP.default =IssueStatus.find_by(id: 1)

    ISSUE_TYPE_MAP={
        '1' => 1, #BUG
        '2' => 2, # new feature
        '3' => 4, # task
        '4' => 2, # improvment
        '6' => 4, # epic
        '5' => 4, # subtask
        '7' => 5, # story
        '8' => 4 # technical task
    }
    ISSUE_TYPE_MAP.default =4
    issues=@doc.xpath('//entity-engine-xml//Issue')
    issuesMap={}
    issues.each { |jiraIssue|

      if Issue.where(jira_id: jiraIssue['id']).take

        issue = Issue.where(jira_id: jiraIssue['id']).take
        issue.estimated_hours=jiraIssue['timeoriginalestimate'].to_f/3600
        issue.status = STATUS_MAP[jiraIssue['status']]
        issue.save
        puts issue
        puts issue.estimated_hours
        if !issue.errors.empty?
          puts issue.errors.full_messages
          puts jiraIssue
        end
        next
      end
      puts jiraIssue['key']+' '+jiraIssue['id']

      if jiraIssue.first_element_child()
        cdata = jiraIssue.search('description').children.find { |e| e.cdata? }
        if (cdata)
          descr=cdata.text
        else
          descr=''
        end
      else
        descr=''
      end
      created=Date.parse(jiraIssue['created'])
      updated=Date.parse(jiraIssue['updated'])
      issue = Issue.new({:subject => jiraIssue['summary'],
                         :description => descr,
                         :project_id => projectMap[jiraIssue['project']].id(),
                         :tracker_id => ISSUE_TYPE_MAP[jiraIssue['type']],
                         :author => usersMap[jiraIssue['reporter']],
                         :priority => IssuePriority.all[2],
                         :assigned_to => usersMap[jiraIssue['assignee']],
                         :status => STATUS_MAP[jiraIssue['status']],
                         :created_on => created,
                         :updated_on => updated,
                         :start_date => created,
                         :estimated_hours=>jiraIssue['timeoriginalestimate'].to_f/3600
                        });
      issue.custom_field_values= {'1' => jiraIssue['key']}
      issue.jira_id=jiraIssue['id']
      issue.save
      issue.created_on=created
      issue.updated_on=updated
      issue.save
      issuesMap[jiraIssue['id']]=issue.id()

      if !issue.errors.empty?
        puts issue.errors.full_messages
        puts jiraIssue
      end
    }

    puts "Import hierarcy"
    # Add issues to its parents
    issues.each { |jiraIssue|
      if jiraIssue["type"]=='5'
        puts "CHILD-"+jiraIssue['key']
        child_issue=Issue.where(jira_id: jiraIssue['id']).take
        if (child_issue && !child_issue.parent_id)
          child_issue.parent_id=Issue.where(jira_id: issuesLinks[jiraIssue['id']]).take.id()
          child_issue.save
          if !child_issue.errors.empty?
            puts child_issue.errors.full_messages
            puts jiraIssue
          end

        end
      end

    }
    # COmments
    puts 'import comments'
    comments=@doc.xpath('//entity-engine-xml//Action')
    comments.each { |jiraComment|
      if jiraComment['type']!='comment'
        next
      end
      comment=Journal.where(jira_id: jiraComment['id']).take
      if comment
        next
      end
      issue=Issue.where(jira_id: jiraComment['issue']).take
      if issue
        comment=Journal.new(
            :journalized_type => 'Issue',
            :user_id => usersMap[jiraComment['author']].id(),
            :journalized_id => issue.id()
        );
        if jiraComment['body']
          comment.notes=jiraComment['body']
        else
          cdata = jiraComment.search('body').children.find { |e| e.cdata? }
          if cdata
            comment.notes=cdata.text
          end


        end
        created=Date.parse(jiraComment['created'])
        comment.created_on=created
        comment.jira_id=jiraComment['id']
        comment.save
        if !comment.errors.empty?
          puts comment.errors.full_messages
          puts jiraComment
        end



      end

    }
=begin
    <Action id="10000" issue="10003" author="klim" type="comment" created="2013-01-08 12:23:53.851" updateauthor="klim" updated="2013-01-08 12:23:53.851">
    <body><![CDATA[Which way are you going to add your comment?

    * Keyboard shortcut: !m.png!
    * Clicking the Comment button below
    * Clicking the Comment button in the top section
    * Using the Operations Dialog keyboard shortcut: !dot.png! and then typing 'comment'
    ]]></body>
    </Action>
=end

    #import time spend
    puts "import worklog"
    worklogs=@doc.xpath('//entity-engine-xml//Worklog')
    worklogs.each { |jiraWorklog|
      timeentry=TimeEntry.where(jira_id: jiraWorklog['id']).take
      if timeentry
        next
      end

      issue=Issue.where(jira_id: jiraWorklog['issue']).take
      if issue
        created=Date.parse(jiraWorklog['startdate'])
        puts issue.custom_field_values[0].value+' '+ jiraWorklog['author']+created.to_s

=begin
        tiementry=TimeEntry.where(project_id: issue.project_id, issue_id: issue.id(),
                        user_id: usersMap[jiraWorklog['author']].id(),
                        ).take();
=end

        timeentry=TimeEntry.new(
            :project_id => issue.project_id,
            :issue_id => issue.id(),
            :hours => jiraWorklog['timeworked'].to_f/3600
        )
        if jiraWorklog['body']
          timeentry.comments=jiraWorklog['body'].slice(0, 249)
        else
          cdata = jiraWorklog.search('body').children.find { |e| e.cdata? }
          if cdata
            timeentry.comments=cdata.text.slice(0, 249)
          end


        end

        timeentry.activity_id=9
        timeentry.user = usersMap[jiraWorklog['author']]
        timeentry.created_on=created
        timeentry.spent_on=created
        timeentry.tmonth=created.month()
        timeentry.tyear=created.year()
        timeentry.tweek=created.cweek()
        timeentry.jira_id=jiraWorklog['id'];
        timeentry.save
        puts timeentry.errors.full_messages
      end

    }

    #IMport attachments

    puts 'import fileattachments'
    fileAttachments=@doc.xpath('//entity-engine-xml//FileAttachment')
    fileAttachments.each { |jiraAttachment|
      issue=Issue.where(jira_id: jiraAttachment['issue']).take
      if Attachment.where(jira_id: jiraAttachment['id']).take
        puts 'attach alredy exists'
        next
      end
      if !issue
        puts 'issue not found'
        next
      end

#id="10810" issue="10813" mimetype="text/plain" filename="robots.txt" created="2013-03-27 18:34:13.639" filesize="2672" author="trakht" zip="0" thumbnailable="0"
      new_attachment=Attachment.new(
          :container => issue, #Issue object defined earlier
          :description => '',
          :author => usersMap[jiraAttachment['author']], #User object defined earlier
          :content_type => jiraAttachment['mime'],
          :filesize => jiraAttachment['filesize'],
          :filename => jiraAttachment['filename']
      )
      new_attachment.jira_id=jiraAttachment['id']
      jiratask=issue.custom_field_values()[0].value
      projectKey=jiratask.split('-')

      file=File.open("jira/data/attachments/#{projectKey[0]}/10000/#{jiratask}/#{jiraAttachment['id']}")
      new_attachment.file=file
      new_attachment.save()
      file.close()


    }


    f.close

    #Rails.logger.debug projects

  end
end
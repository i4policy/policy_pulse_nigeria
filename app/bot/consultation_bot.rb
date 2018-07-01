include Facebook::Messenger
Facebook::Messenger::Subscriptions.subscribe(access_token: ENV["ACCESS_TOKEN"])


# Settings for chatbot presentation page - adds a description and a Get Started button
Facebook::Messenger::Profile.set({
  greeting:[
    {
      locale: 'default',
      text: "National ICT Innovation and Entrepreneurship Policy Vision wants to give citizens the chance to participate and shape national economic policy."
    }
  ],
  get_started: {
      payload: "GET_STARTED"
  },
  persistent_menu: [
    { locale: 'default',
      composer_input_disabled: false,
      call_to_actions: [
        { title:"Policy Table of Contents",
          type:"nested",
          call_to_actions:[
            { title: 'Introduction',
              type: 'postback',
              payload: 'INTRO'
            },
            { title: 'Digital Infrastructure',
              type: 'postback',
              payload: 'SECTION_1'
            },
            { title: 'Education Reform',
              type: 'postback',
              payload: 'SECTION_2'
            },
            { title: 'Supporting the Ecosystem',
              type: 'postback',
              payload: 'SECTION_3'
            },
            { title: 'Direct Support for Startups',
              type: 'postback',
              payload: 'SECTION_4'
            }
          ]
        },
        {
          type:"web_url",
          title:"Visit our website",
          url:"http://www.messenger.com/",
          webview_height_ratio:"full"
        }
      ]
    }
  ]
}, access_token: ENV['ACCESS_TOKEN'])

VALID_EMAIL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

Bot.on :message do |message|
  handle_message(message, message.quick_reply)
end

def handle_message(message, quick_reply)
  messenger_id = message.sender["id"]
  current_user = get_user(messenger_id)
  legislation = Legislation.last
  consultation_id = Consultation.find_by(user_id: current_user.id)
  message.mark_seen
  p message
  sleep(1.5)

  if quick_reply && !quick_reply.blank?
    current_user.checkpoint = quick_reply
    current_user.save
    commands = quick_reply.split('/')
  else
    commands = []
    feedback_ids = (current_user.checkpoint.split('/').second || "").split(',')

    if current_user.checkpoint.start_with?("FEEDBACK")
      consultation_id, section_id, clause_id, question_index = feedback_ids
      set_answer(message, user_id: current_user.id, clause_id: clause_id, question_index: question_index)
      current_user.checkpoint = ""
      current_user.save

      if last_clause?(section_id, clause_id)
        if last_section?(section_id)
          outboard(message)
        else
          next_section(message, consultation_id: consultation_id, section_id: section_id.to_i + 1, user: current_user)
        end
      else
        next_clause(message, consultation_id: consultation_id, clause_id: clause_id.to_i + 1, section_id: section_id, user: current_user)
      end
    elsif current_user.checkpoint.start_with?("ASK_FOR_EMAIL")

      if message.text.match(VALID_EMAIL_REGEX)
        messenger_id = message.sender["id"]
        current_user.email = message.text
        current_user.checkpoint = "USAGE_EXPLANATION"
        current_user.save

        usage_explanation(message)
      else
        message.typing_on
        message.reply(
          text: "Oops, it looks like you didn't enter a valid e-mail address. Please enter it again."
        )
      end
    else
      message.typing_on
      message.reply(
        text: "Oops! I didn't understand your message, please answer the question with one of the options below:"
      )

      unless current_user.checkpoint.blank?
        handle_message(message, current_user.checkpoint)
      end
    end
  end


  case commands.first

    when "ASK_FOR_EMAIL"
      # current_user.checkpoint = "Please enter your e-mail address."
      # current_user.save
      ask_for_user_email(message)

    when "USAGE_EXPLANATION"
      usage_explanation(message)

    when "START_CONSULTATION"
      start_consultation(message, current_user, legislation)

    when "SHOW_QUESTION"
      show_question(message, options: commands.last)

    when "SHOW_SECTION"
      ids = commands.last.split(',')
      consultation_id, section_id, clause_id, question_index = ids
      show_section(message, consultation_id: consultation_id, section_id: section_id.to_i, user: current_user)

    when "SHOW_CLAUSE"
      ids = commands.last.split(',')
      consultation_id, section_id, clause_id, question_index = ids
      show_clause(message, consultation_id: consultation_id, clause_id: clause_id.to_i, section_id: section_id, user: current_user)

    when "ANSWER"
      options = commands.last
      ids = options.split(',')
      consultation_id, section_id, clause_id, question_index = ids

      set_answer(message, user_id: current_user.id, clause_id: clause_id, question_index: question_index)

      if last_question?(clause_id, question_index)
        if last_clause?(section_id, clause_id)
          if last_section?(section_id)
            outboard(message)
          else
            next_section(message, consultation_id: consultation_id, section_id: section_id.to_i + 1, user: current_user)
          end
        else
          next_clause(message, consultation_id: consultation_id, clause_id: clause_id.to_i + 1, section_id: section_id, user: current_user)
        end
      else
        question_index = question_index.to_i + 1
        ids = [consultation_id, section_id, clause_id, question_index]
        show_question(message, options: ids.join(','))
      end

    when "FEEDBACK"
      options = commands.last
      ids = options.split(',')
      consultation_id, section_id, clause_id, question_index = ids

      if message.text =="No"
        if last_clause?(section_id, clause_id)
          if last_section?(section_id)
            outboard(message)
          else
            next_section(message, consultation_id: consultation_id, section_id: section_id.to_i + 1, user: current_user)
          end
        else
          next_clause(message, consultation_id: consultation_id, clause_id: clause_id.to_i + 1, section_id: section_id, user: current_user)
        end
      else
        question_index = question_index.to_i
        ids = [consultation_id, section_id, clause_id, question_index]
        # current_user.checkpoint = "Please suggest your revision"
        # current_user.save
        # feedback_ids = ids
        show_feedback_question(message, options: ids.join(','))
      end

    when "GET_STARTED"
      greet_current_user(message)
    when "INTRO"
      skip_to_section(message, consultation_id: consultation_id, section_id: 1)
    when "SECTION_1"
      skip_to_section(message, consultation_id: consultation_id, section_id: 2)
    when "SECTION_2"
      skip_to_section(message, consultation_id: consultation_id, section_id: 3)
    when "SECTION_3"
      skip_to_section(message, consultation_id: consultation_id, section_id: 4)
    when "SECTION_4"
      skip_to_section(message, consultation_id: consultation_id, section_id: 5)
  end

end

Bot.on :postback do |postback|

  handle_message(postback, postback.payload)

end

# INTRO AND GOODBYE MESSAGES

def greet_current_user(postback)
  messenger_id = postback.sender["id"]
  current_user = get_user(messenger_id)
  postback.reply(
    text: "Welcome #{current_user.first_name} !"
  )
  sleep(1)
  postback.reply(
    text: "I'm the official consultation chatbot for the National ICT Innovation and Entrepreneurship Policy Vision."
  )
  sleep(2)
  postback.reply(
    text: "We need your help to create and shape a unifying policy vision for transforming Nigeria's economy and accelerating economic growth. And to do so, we need your input.",
    quick_replies:[
      {
        content_type: 'text',
        title: "I want to help!",
        payload: 'ASK_FOR_EMAIL'
      }
    ]
  )
end

def ask_for_user_email(message)
  message.typing_on
  message.reply(
    text: "Before we begin, please enter your e-mail. We will send you the results of the nationwide consultation once it is over, as well as any new policy updates so that you can participate in future consultations."
  )
end

def usage_explanation(message)
  message.typing_on
  message.reply(
  text: "The proposed policy vision is composed of an introduction and 4 sections. Each section has several clauses and you are invited to give your feedback on each one. If you want to get an overview of the policy at any time, or skip to a specific section, use the menu below."
  )
  sleep(1)
  message.typing_on
  message.reply(
    text: "Your input on each section is saved as you go. You will be asked 2 standard questions for each clause, and then be given the opportunity to provide more open feedback should you wish to."
    )
  sleep(1)
  message.typing_on
  message.reply(
    text: "The standard questions can be answered with a 1 to 5 scale. 1 means you do not agree at all, while 5 means you completely agree.",
    quick_replies:[
      {
        content_type: "text",
        title: "I'm ready!",
        payload: 'START_CONSULTATION'
      }
    ]
  )
end

def outboard(message)
  messenger_id = message.sender["id"]
  current_user = get_user(messenger_id)
  message.typing_on
  message.reply(
    text: "That's it ! Thank you #{current_user.first_name} for answering all of our questions. Your input has been super valuable to us and will help shape Nigerian economic policy."
  )
  sleep(2)
  message.typing_on
  message.reply(
    attachment: {
      type: 'template',
      payload: {
        template_type: 'button',
        text: 'If you want to dive deeper into the process, please visit our web app by clicking on the button below.',
        buttons: [
          { type: 'web_url',
            url:"https://www.facebook.com",
            title: 'Policy Pulse',
            webview_height_ratio: "full"
          }
        ]
      }
    }
  )
  sleep(2)
  message.typing_on
  message.reply(
    text: "And if you want to make an even bigger impact, please share out chatbot with your friends, family, and other citizens. The more input we have, the more this policy will reflect the needs of the people its meant to serve!"
  )
  sleep(2)
  message.typing_on
  message.reply(
    {
      attachment: {
        type: "template",
        payload: {
          template_type: "generic",
          elements: [
            {
              title: "Share Policy Pulse",
              #subtitle: "<TEMPLATE_SUBTITLE>",
              #image_url: "<IMAGE_URL_TO_DISPLAY>",
              buttons: [
                {
                  type: "element_share",
                  share_contents: {
                    attachment: {
                      type: "template",
                      payload: {
                        template_type: "generic",
                        elements: [
                          {
                            title: "I just completed the policy consultation",
                            subtitle: "I'm helping shape democracy, join me!",
                            #To Do: add image to share dialog and default action link to website
                            #image_url: "https://bot.peters-hats.com/img/hats/fez.jpg",
                            # default_action: {
                            #   type: "web_url",
                            #   url: "https://www.facebook.com"
                            # },
                            buttons: [
                              {
                                type: "web_url",
                                #this url is the id of the consultation bot, it needs to be changed if we use a different FB bot
                                url: "https://www.facebook.com/messages/t/635113713524558",
                                title: "Start Consultation"
                              }
                            ]
                          }
                        ]
                      }
                    }
                  }
                }
              ]
            }
          ]
        }
      }
    }
  )
end

#NAVIGATION

def start_consultation(message, user, legislation)
  consultation = Consultation.find_or_create_by(user: user, legislation: legislation)
  ids = [consultation.id, 1, 1, 1]
  section = Section.find(1)
  clause = Clause.find(1).content.split(".")
  message.typing_on
  message.reply(
    text: "#{clause[0..1].join('.')}"
  )
  sleep(2)
  message.typing_on
  message.reply(
    text: "#{clause[2].gsub("\n",' ')}."
  )
  sleep(2)
  message.typing_on
  message.reply(
    text: "#{clause[3].gsub("\n",' ')}.",
    quick_replies:[
      {
        content_type: "text",
        title: "Got it!",
        payload: "SHOW_QUESTION/#{ids.join(',')}"
      }
    ]
  )
end

def next_clause(message, consultation_id:, section_id:, clause_id:, user:)
  text = ["Moving on to the next clause of this section...", "OK, let's go to the next clause of this section...", "Next clause! Are you ready ?", "On to the next clause..."]

  message.typing_on
  message.reply(
    text: text.sample
  )
  sleep(1)

  show_clause(message, consultation_id: consultation_id, section_id: section_id, clause_id: clause_id, user: user)
end

def show_clause(message, consultation_id:, section_id:, clause_id:, user:)
  ids = [consultation_id, section_id, clause_id, 1]
  clause = Clause.find(clause_id)
  user.checkpoint = "SHOW_CLAUSE/#{ids.join(',')}"
  user.save

  text = ["Here it is:", "This is it:", "Here's what it says:", "This is what it contains:"]
  message.typing_on
  message.reply(
    text: text.sample
  )
  sleep(2)
  button_titles = ["Got it !", "Understood !", "OK !"]
  message.typing_on
  message.reply(
    text: "#{clause.content}",
    quick_replies:[
      {
        content_type: "text",
        title: button_titles.sample,
        payload: "SHOW_QUESTION/#{ids.join(',')}"
      }
    ]
  )

end

def next_section(message, consultation_id:, section_id:, user:)
  section = Section.find(section_id)
  clause = section.clauses.first
  ids = [consultation_id, section_id, clause.id, 1]

  text = ["Next section ! Here we're going to talk about #{section.title}.", "Moving on to the next section...the subject is #{section.title}."]
  message.typing_on
  message.reply(
    text: text.sample
  )
  sleep(1)
  show_section(message, consultation_id: consultation_id, section_id: section_id, user: user)
end

def show_section(message, consultation_id:, section_id:, user:)
  section = Section.find(section_id)
  clause = section.clauses.first
  ids = [consultation_id, section_id, clause.id, 1]

  user.checkpoint = "SHOW_SECTION/#{ids.join(',')}"
  user.save

  text = ["Let's start with the first clause of the section:", "Here's the first clause of the section:"]
  message.typing_on
  message.reply(
    text: text.sample
  )
  sleep(2)
  button_titles = ["Got it !", "Understood !", "OK !"]
  message.typing_on
  message.reply(
    text: "#{clause.content}",
    quick_replies:[
      {
        content_type: "text",
        title: button_titles.sample,
        payload: "SHOW_QUESTION/#{ids.join(',')}"
      }
    ]
  )
end

def skip_to_section(message, consultation_id:, section_id:)
  section = Section.find(section_id)
  clause = section.clauses.first
  ids = [consultation_id, section_id, clause.id, 1]
  message.typing_on
  message.reply(
    text: "Skipping to #{section.title}..."
  )
  sleep(1)
  unless section.id == 1
    text = ["Let's start with the first clause of the section:", "Here's the first clause of the section:"]
    message.typing_on
    message.reply(
      text: text.sample
    )
    sleep(2)
  end
  message.typing_on
  message.reply(
    text: "#{clause.content}",
    quick_replies:[
      {
        content_type: "text",
        title: "Got it!",
        payload: "SHOW_QUESTION/#{ids.join(',')}"
      }
    ]
  )
end

# Question messages

def show_question(message, options:)
  ids = options.split(',')
  consultation_id, section_id, clause_id, question_index = ids
  clause = Clause.find(clause_id)

  if last_question?(clause_id, question_index)
    # Skipping the last question for now, might need to accept a typed response
    message.typing_on
    message.reply(
      text: "Would you like to provide a suggestion or a revision to this clause ?",
      quick_replies: ["Yes", "No"].map do |answer|
        {
          content_type:"text",
          title: answer,
          payload: "FEEDBACK/#{options}"
        }
      end
    )
  else
    message.typing_on
    message.reply(
      text: clause.questions[question_index.to_i - 1].content,
      quick_replies: ["1","2","3","4","5"].map do |number|
        {
          content_type: "text",
          title: number,
          payload: "ANSWER/#{options}"
        }
      end
    )
    # if question_index == "1"
    #   text = "Please answer using a scale of 1 to 5. Answering with 1 means that it is not at all representative, while 5 means it is completely representative."
    # else
    #   text = "Please answer the question using the same 1 to 5 scale."
    # end
    # sleep(1)
    # message.typing_on
    # message.reply(
    #   text: text,
    #   quick_replies: ["1","2","3","4","5"].map do |number|
    #     {
    #       content_type: "text",
    #       title: number,
    #       payload: "ANSWER/#{options}"
    #     }
    #   end
    # )
  end
end

def show_feedback_question(message, options:)
  ids = options.split(',')
  consultation_id, section_id, clause_id, question_index = ids
  clause = Clause.find(clause_id)
  feedback_text = clause.questions[question_index.to_i - 1].content
  message.typing_on
  message.reply(
    text: feedback_text
  )
end

# User methods
def get_user(messenger_id)
  user = User.find_by(messenger_id: messenger_id)
  # If user does not exist, create new
  user = create_new_user(messenger_id) unless user

  user
end

# TO DO: how do we set valid e-mail and password through Messenger (as these are
# required fields to create a new user b/c of Devise). Method below sets a dummy
# e-mail and password based on the user's unique Messenger ID.

def create_new_user(messenger_id)
  user = User.new(messenger_id: messenger_id)
  # Get user info from Messenger User Profile API
  url = "https://graph.facebook.com/v2.6/#{messenger_id}?fields=first_name,last_name&access_token=#{ENV["ACCESS_TOKEN"]}"
  user_data = api_call(url)
  # Store user's name
  user.first_name = user_data["first_name"]
  user.last_name = user_data["last_name"]
  user.email = "#{messenger_id}@mail.com"
  user.password = "#{messenger_id}"

  user.save!
end

def api_call(url)
  require 'json'
  require 'open-uri'
  user_data = JSON.parse(open(url).read)
end

def set_answer(message, user_id:, clause_id:, question_index:)
  clause = Clause.find(clause_id)
  question = clause.questions[question_index.to_i - 1]
  # if the user has never answered the question
  if Question.find(question.id).answers.where(user_id: user_id).length == 0
    answer = Answer.new(question: question, user_id: user_id, content: message.text)
    answer.save
  # else update his already existing answer
  else
    answer = Answer.find_by(question_id: question, user_id: user_id)
    answer.content = message.text
    answer.save
  end
end

def last_question?(clause_id, question_index)
  clause = Clause.find(clause_id)
  clause_question_count = clause.questions.count

  if clause_question_count == question_index.to_i
    true
  else
    false
  end
end

def last_clause?(section_id, clause_id)
  section = Section.find(section_id)
  clause = Clause.find(clause_id)
  if section.clauses.last == clause
    true
  else
    false
  end
end

def last_section?(section_id)
  section = Section.find(section_id)
  return true if section == Section.last
end

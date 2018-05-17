require 'aws-sdk-ses' # v2: require 'aws-sdk'
require './emailer.rb'
require 'dotenv'
require 'mime'

module WorkForwardNola
  # Class for sending out emails through AWS
  class AwsEmailer < Emailer

    Dotenv.load

    def initialize(access, secret)
      begin
        Aws.config.update(credentials: Aws::Credentials.new(access, secret), region: 'us-east-1')
        @ses = Aws::SES::Client.new
      rescue Aws::SES::Errors::ServiceError => error
        throw Aws::SES::Errors::ServiceError.new("Error configuring AWS SES client. Error message: #{error}")
      end
    end

    def send_email(recipients, sender, subject, text_body, html_body, attachment_file = nil)
      if recipients == nil
        recipients = cc
      end
      msg_mixed = MIME::Multipart::Mixed.new
      unless attachment_file.nil?
        attachment = MIME::Application.new(Base64::encode64(open(attachment_file,"rb").read))
        attachment.transfer_encoding = 'base64'
        attachment.disposition = 'attachment'
        msg_mixed.attach(attachment, 'filename' => attachment_file)
      end
      msg_body = MIME::Multipart::Alternative.new
      msg_body.add(MIME::Text.new(text_body,'plain'))
      msg_body.add(MIME::Text.new(html_body,'html'))
      msg_mixed.add(msg_body)
      msg = MIME::Mail.new(msg_mixed)
      msg.subject = subject
      # Try to send the email.
      begin
        # Verify the emails, this will add them to the verified emails
        # if using sandboxes.

        # check_emails sender
        # check_emails recipient
        # check_emails cc
        # check_emails bcc
        # check_emails reply_to

        # Provide the contents of the email.

        resp = @ses.send_raw_email({
          source: sender,
          destinations: recipients,
          raw_message: {
          data: msg.to_s
          }
        })
        #msg.headers.set('X-SES-CONFIGURATION-SET',configsetname)
=begin
        email_config_data = {
          destination: { to_addresses: [recipient, cc, bcc] },
          message: {
            subject: { charset: encoding, data: subject },
            body: {
              html: { charset: encoding, data: html_body },
              text: { charset: encoding, data: text_body }
            }
          },
          source: sender
        }
=end
        # Email validation?
        # if not cc.nil?
        #  email_config_data[:destination][:cc_addresses] = as_email_array(cc)
        # end
        # if not bcc.nil?
        #  email_config_data[:destination][:bcc_addresses] = as_email_array(bcc)
        # end
        # if not reply_to.nil?
        #  email_config_data[:reply_to] = reply_to  
        #  not sure about the key on this one.
        # end
        #resp = @ses.send_email(email_config_data)
        puts "Email sent to #{recipients.inspect}: #{resp.inspect}"
      rescue Aws::SES::Errors::ServiceError => error
        # If something goes wrong, display an error message.
        throw error
      end
    end

    private

    # Used to verify emails for use in AWS sandbox environment
    def check_emails(emails)
      return if emails.nil?
      if emails.respond_to? :each
        emails.each { |e| @ses.verify_email_identity email_address: e }
      else
        @ses.verify_email_identity email_address: emails
      end
    end
  
    def as_email_array(emails)
      return emails if emails.respond_to? :each
      [emails]
    end
  end
end
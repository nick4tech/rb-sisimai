module Sisimai::Lhost
  # Sisimai::Lhost::MessageLabs parses a bounce email which created by Symantec.cloud: formerly MessageLabs.
  # Methods in the module are called from only Sisimai::Message.
  module MessageLabs
    class << self
      require 'sisimai/lhost'

      Indicators = Sisimai::Lhost.INDICATORS
      Boundaries = ['Content-Type: text/rfc822-headers'].freeze
      StartingOf = { message: ['Content-Type: message/delivery-status'] }.freeze
      MessagesOf = {
        'userunknown'   => ['542 ', ' Rejected', 'No such user'],
        'securityerror' => ['Please turn on SMTP Authentication in your mail client'],
      }.freeze

      # Parse bounce messages from Symantec.cloud(MessageLabs)
      # @param  [Hash] mhead    Message headers of a bounce email
      # @param  [String] mbody  Message body of a bounce email
      # @return [Hash]          Bounce data list and message/rfc822 part
      # @return [Nil]           it failed to parse or the arguments are missing
      def inquire(mhead, mbody)
        # X-Msg-Ref: server-11.tower-143.messagelabs.com!1419367175!36473369!1
        # X-Originating-IP: [10.245.230.38]
        # X-StarScan-Received:
        # X-StarScan-Version: 6.12.5; banners=-,-,-
        # X-VirusChecked: Checked
        return nil unless mhead['x-msg-ref']
        return nil unless mhead['from'].include?('MAILER-DAEMON@messagelabs.com')
        return nil unless mhead['subject'].start_with?('Mail Delivery Failure')

        fieldtable = Sisimai::RFC1894.FIELDTABLE
        permessage = {}     # (Hash) Store values of each Per-Message field

        dscontents = [Sisimai::Lhost.DELIVERYSTATUS]
        emailparts = Sisimai::RFC5322.part(mbody, Boundaries)
        bodyslices = emailparts[0].split("\n")
        readslices = ['']
        readcursor = 0      # (Integer) Points the current cursor position
        recipients = 0      # (Integer) The number of 'Final-Recipient' header
        commandset = []     # (Array) ``in reply to * command'' list
        v = nil

        while e = bodyslices.shift do
          # Read error messages and delivery status lines from the head of the email to the previous
          # line of the beginning of the original message.
          readslices << e # Save the current line for the next loop

          if readcursor == 0
            # Beginning of the bounce message or message/delivery-status part
            readcursor |= Indicators[:deliverystatus] if e.start_with?(StartingOf[:message][0])
            next
          end
          next if (readcursor & Indicators[:deliverystatus]) == 0
          next if e.empty?

          if f = Sisimai::RFC1894.match(e)
            # "e" matched with any field defined in RFC3464
            next unless o = Sisimai::RFC1894.field(e)
            v = dscontents[-1]

            if o[-1] == 'addr'
              # Final-Recipient: rfc822; kijitora@example.jp
              # X-Actual-Recipient: rfc822; kijitora@example.co.jp
              if o[0] == 'final-recipient'
                # Final-Recipient: rfc822; kijitora@example.jp
                if v['recipient']
                  # There are multiple recipient addresses in the message body.
                  dscontents << Sisimai::Lhost.DELIVERYSTATUS
                  v = dscontents[-1]
                end
                v['recipient'] = o[2]
                recipients += 1
              else
                # X-Actual-Recipient: rfc822; kijitora@example.co.jp
                v['alias'] = o[2]
              end
            elsif o[-1] == 'code'
              # Diagnostic-Code: SMTP; 550 5.1.1 <userunknown@example.jp>... User Unknown
              v['spec'] = o[1]
              v['diagnosis'] = o[2]
            else
              # Other DSN fields defined in RFC3464
              next unless fieldtable[o[0]]
              v[fieldtable[o[0]]] = o[2]

              next unless f
              permessage[fieldtable[o[0]]] = o[2]
            end
          else
            # Continued line of the value of Diagnostic-Code field
            next unless readslices[-2].start_with?('Diagnostic-Code:')
            next unless e.start_with?(' ')
            v['diagnosis'] << ' ' << Sisimai::String.sweep(e)
            readslices[-1] = 'Diagnostic-Code: ' << e
          end
        end
        return nil unless recipients > 0

        dscontents.each do |e|
          # Set default values if each value is empty.
          e['lhost'] ||= permessage['rhost']
          permessage.each_key { |a| e[a] ||= permessage[a] || '' }
          e['command']   = commandset.shift || ''
          e['diagnosis'] = Sisimai::String.sweep(e['diagnosis'])

          MessagesOf.each_key do |r|
            # Verify each regular expression of session errors
            next unless MessagesOf[r].any? { |a| e['diagnosis'].include?(a) }
            e['reason'] = r
            break
          end
        end

        return { 'ds' => dscontents, 'rfc822' => emailparts[1] }
      end
      def description; return 'Symantec.cloud http://www.messagelabs.com'; end
    end
  end
end


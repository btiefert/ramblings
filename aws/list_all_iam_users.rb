#!/usr/bin/ruby

require "aws-sdk"

# IAM Account Alias
@iam = AWS::IAM.new
puts @iam.account_alias
puts "===\n"

@iam = AWS::IAM.new
@iam.users.each do |user|
	puts user.name
end

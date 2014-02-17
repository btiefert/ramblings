#!/usr/bin/ruby

require 'aws-sdk'

# IAM Account Alias
iamaa = AWS::IAM.new
puts iamaa.account_alias
puts "===\n"

# Output name of each bucket in this account
s3 = AWS::S3.new
s3.buckets.each do |bucket|
	puts bucket.name
end

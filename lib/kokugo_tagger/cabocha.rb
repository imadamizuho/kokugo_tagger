# -*- coding: utf-8 -*-

module KokugoTagger::Cabocha
	module_function
	def parse(file = @source)
		document = KokugoTagger::Cabocha::Document.new
		sentence, chunk = nil, nil
		file.each_line do |line|
			sentence ||= KokugoTagger::Cabocha::Sentence.new
			case line
			when /^EOS/
				sentence.each{|chunk| chunk.detect_structure} # sem_headとsyn_headの独自判定
				document << sentence
				sentence, chunk = nil, nil
			when /^\*/
				chunk = KokugoTagger::Cabocha::Chunk.new(line)
				sentence << chunk
				chunk.sentence = sentence
			when /^#/
				# nothing
			else
				token = KokugoTagger::Cabocha::Token.new(line)
				chunk.tokens << token
			end
		end
		return document
	end
end

class KokugoTagger::Cabocha::Document < Array
end

class KokugoTagger::Cabocha::Sentence < Array
end

class KokugoTagger::Cabocha::Chunk
	attr_accessor :info, :id, :link, :rel, :sem_head_id, :syn_head_id, :ext, :tokens, :sentence
	def initialize(line)
		@info = line.chomp.split(/\s/)[1..-1]
		@id = @info[0].to_i
		@link = @info[1].to_i
		@rel = @info[1].delete("-0-9")
		@sem_head_id = @info[2].split('/')[0].to_i
		@syn_head_id = @info[2].split('/')[1].to_i
		@ext = @info[4]
		@tokens = []
	end
	def detect_structure
		sem_head_id, syn_head_id = 0, 0
		@tokens.each_with_index do |token, num|
			if token.pos =~ /^(助詞|助動詞)/
				syn_head_id = num
			elsif token.pos !~ /^(補助記号|空白)/
				sem_head_id = num if sem_head_id == syn_head_id
				syn_head_id = num
			end
		end
		@sem_head_id, @syn_head_id = sem_head_id, syn_head_id
	end
	def text
		@tokens.map{|token| token.text}.join
	end
end

class KokugoTagger::Cabocha::Token
	attr_accessor :info, :text, :pos, :ctype, :cform
	def initialize(line)
		text, info = line.chomp.split("\t")
		@info = info.split(",")
		@text = text
		@pos = @info[0, 4].delete_if{|s| s == '*'}.join('-')
		@ctype = @info[4] 
		@cform = @info[5]
	end
end

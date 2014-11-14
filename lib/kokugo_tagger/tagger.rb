# -*- coding: utf-8 -*-
require 'csv'

module KokugoTagger
	module_function
	def annotate(file)
		file.each_line do |line|
			data = CabochaParser.parse(line)
			method_name = data[:type].downcase.to_sym
			method(method_name).call(data) if methods.include?(method_name)
			puts line
		end
	end
	def chunk(data)
		@chunks ||= []
		@chunks << @chunk = data
		@lpos ||= 0
		@chunk.update start:@lpos, end:@lpos, text:'', pos:nil, pred:nil, conj:nil
	end
	def token(data)
		@lpos += data[:text].size
		@chunk[:end] = @lpos
		@chunk[:text] += data[:text]
		pos data
		cform data
	end
	def segment_s(data)
	end
	def attr(data)
	end
	def eos(data)
		before_eos
		@chunks.each do |chunk|
			puts '#! SEGMENT_S bccwj-kok:Bnst %d %d "%s"' % [chunk[:start], chunk[:end], chunk[:text]]
			puts '#! ATTR bccwj-kok:pred "%s述語"' % chunk[:pos] if chunk[:pred]
			puts '#! ATTR bccwj-kok:conj "%s"' % chunk[:conj] if chunk[:conj]
		end
		@chunks, @chunk, @lpos, @segments = nil
	end
	def pos(token)
		case token[:pos]
		when /^(名詞|代名詞|接尾辞-名詞的)/
			@chunk.update pos:'名詞', pred:nil, conj:nil
		when /^(形状詞|接尾辞-形状詞的)/
			@chunk.update pos:'形状詞', pred:nil, conj:nil
		when /^連体詞/
			@chunk.update pos:'連体詞', pred:nil, conj:'修飾(連体)'
		when /^副詞/
			@chunk.update pos:'副詞', pred:nil, conj:'修飾(連用)'
		when /^接続詞/
			@chunk.update pos:'接続詞', pred:nil, conj:'接続'
		when /^感動詞/
			@chunk.update pos:'感動詞', pred:nil, conj:'独立'
		when /^(動詞|接尾辞-動詞的)/
			@chunk.update pos:'動詞', pred:true, conj:nil
		when /^(形容詞|接尾辞-形容詞的)/
			@chunk.update pos:'形容詞', pred:true, conj:nil
		when /^助動詞/
			@chunk.update pred:true, conj:nil
		when /^助詞-格助詞/
			case token[:text]
			when 'が'
				@chunk.update conj:'主語'
			when 'の', 'との', 'という', 'といった'
				@chunk.update conj:'修飾(連体)'
			else
				@chunk.update conj:'補語'
			end
		when /^(助詞-副助詞|助詞-係助詞)/
			@chunk.update conj:'修飾(連用)'
		when /^助詞-接続詞/
			@chunk.update pred:true, conj:'接続'
		when /^助詞-終助詞/
			@chunk.update pred:true, conj:nil
		when /^助詞-準体助詞/
			@chunk.update conj:nil
		end
	end
	def cform(token)
		case token[:cform]
		when /^語幹/
		when /^(未然形|連用形|仮定形|已然形)/
			@chunk.update conj:'接続'
		when /^(意志推量形|連体形)/
			@chunk.update conj:'修飾(連体)'
		when /^(終止形|命令形)/
			@chunk.update conj:nil
		end			
	end
	def before_eos
		# 属性を付与できなかった文節に対して、係り受けを利用して属性を補完
		# 連用成分を受ける文節を述語とみなす
		@chunks.each do |chunk|
			chunk[:pred] ||= @chunks.any?{|_chunk| _chunk[:link] == chunk[:id] && _chunk[:conj] =~ /^(主語|補語|修飾\(連用\)|接続)$/}
		end
		# 述語にかかる文節を修飾(連用)とみなす
		@chunks.each do |chunk|
			chunk[:conj] = '修飾(連用)' if chunk[:conj] == nil && @chunks.any?{|_chunk| _chunk[:id] == chunk[:link] && _chunk[:pred]}
		end
		# 述語項構造が付与されている文節を補語にする
		@chunks.each do |chunk|
			next if chunk[:link] == '-1' || chunk[:arg] == nil
			next unless chunk[:conj] == nil || chunk[:conj] == '修飾(連用)'
			pred = @chunks[chunk[:link].to_i]
			if chunk[:arg] == 'Ga' and pred[:passive] == nil
				chunk[:conj] = '主語'
			elsif chunk[:arg] == 'O' and pred[:passive] == '直接'
				chunk[:conj] = '主語'
			else
				chunk[:conj] = '補語'
			end
		end
	end
end

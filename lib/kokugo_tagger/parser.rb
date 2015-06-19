# -*- coding: utf-8 -*-
require 'csv'

module CabochaParser
	def parse(line)
		case line.chomp
		when /^#/
			return parse_excab(line)
		when /^\*/
			return parse_chunk(line)
		when 'EOS'
			return {type: 'EOS'}
		when ''
			return nil
		else
			return parse_token(line)
		end
	end
	def parse_excab(line)
		line = line.gsub('\"', '""')
		null, type, *data = CSV.parse_line(line.chomp, col_sep:' ')
		case type
		when 'SEGMENT', 'SEGMENT_S', 'LINK', 'LINK_S'
			excab = {type: type, name: data[0], start: data[1].to_i, end: data[2].to_i, comment: data[3]}
		when 'GROUP', 'GROUP_S'
			excab = {type: type, name: data[0], member: data[1..-2], comment: data[-1]}
		when 'ATTR'
			excab = {type: type, name: data[0], value: data[1]}
		end
		return excab
	end
	def parse_chunk(line)
		null, id, dep, part, score = line.chomp.split("\s")
		link, rel = dep[0..-2], dep[-1]
		head, func = part.split('/')
		chunk = {type: 'CHUNK', id: id, link: link, rel: rel, head: head, func: func, score: score}
		return chunk
	end
	def parse_token(line)
		text, attrs, ne = line.chomp.split("\t")
		attrs = CSV.parse_line(attrs, col_sep:',')
		pos = attrs[0, 4].delete_if{|item| item.empty?}.join('-')
		token = {type: 'TOKEN', text: text, ne: ne, pos: pos, ctype: attrs[4], cform: attrs[5]}
		return token
	end
	module_function :parse, :parse_excab, :parse_chunk, :parse_token
end

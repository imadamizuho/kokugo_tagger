# -*- coding: utf-8 -*-

module KokugoTagger
	module_function
	def annotate(source, model, enc)
		enc ||= "UTF-8"
		source.set_encoding enc
		source_0, source_1 = KokugoTagger::Duplicator.duplicate(source, 2)
		converter = KokugoTagger::Converter.connect(source_0)
		yamcha = KokugoTagger::Yamcha.connect(converter, model)
		merger = KokugoTagger::Merger.connect(yamcha, source_1)
		merger.each_line{|line| puts line }
	end
	def convert(source)
		converter = KokugoTagger::Converter.connect(source)
		converter.each_line{|line| puts line }
	end
	def learn(source_dir, model, enc)
		model ||= "kokugo"
		enc ||= "UTF-8"
		model = File.basename(model, ".model")
		KokugoTagger::Learner.learn source_dir, model, enc
	end
	def validation(source_dir, enc, k)
		enc ||= "UTF-8"
		k_num ||= 3
		KokugoTagger::Learner.validation source_dir, enc, k
	end
end

module KokugoTagger::Duplicator
	module_function
	def duplicate(source, number = 2)
		pipes = number.times.map{ IO.pipe("UTF-8") }
		Thread.fork do
			source.each_line { |line| pipes.each{|r, w| w.puts line } }
			pipes.each{|r, w| w.close}
		end.abort_on_exception = true
		return pipes.map{|r, w| r }
	end
end

module KokugoTagger::Converter
	module_function
	def connect(source)
		read, write = IO.pipe("UTF-8")
		Thread.fork do
			self.process source, write
			write.close
		end.abort_on_exception = true
		return read
	end
	def process(source, output)
		buffer = ""
		source.each_line do |line|
			buffer << line
			self.flush(buffer, output) if line.chomp == "EOS"
		end
	end
	def flush(buffer, output)
		document = KokugoTagger::Cabocha.parse(buffer)
		document.each do |sentence|
			sentence.each { |chunk| output.puts chunk_features(chunk).join(" ") }
			output.puts
		end
		buffer.clear
	end
	def token_features(token)
		return %w(* * * *) unless token
		text, pos, cform = token.text, token.pos.split('-'), token.cform.split('-')
		features = [text, pos[0], pos[1], cform[0]].map{|f| f || '*'}
		return features
	end
	def chunk_features(chunk)
		tokens = [sem_head(chunk), case_marker(chunk), syn_head(chunk), punct(chunk), sem_head(link_to(chunk))]
		features = tokens.map{|token| token_features(token)}
		return [chunk.text, features, chunk.rel].flatten
		# return [chunk.text, features, chunk.ext].flatten
	end
	def sem_head(chunk)
		return nil unless chunk
		chunk.tokens[chunk.sem_head_id]
	end
	def case_marker(chunk)
		return nil unless chunk
		chunk.tokens.find{|token| token.pos.split('-')[1] == '格助詞'}
	end
	def syn_head(chunk)
		return nil unless chunk
		chunk.tokens[chunk.syn_head_id]
	end
	def punct(chunk)
		return nil unless chunk
		chunk.tokens[chunk.syn_head_id + 1]
	end
	def link_to(chunk)
		chunk.sentence[chunk.link] if chunk.link != -1
	end
end

module KokugoTagger::Yamcha
	module_function
	def connect(source, model)
		model ||= File.dirname(__FILE__) + "/kokugo.model"
		io = IO.popen("yamcha -m \"#{model}\"", "r+", encoding: "UTF-8")
		Thread.fork {
			source.each_line{|line| io.puts line }
			io.close_write
		}.abort_on_exception = true
		return io
	end
end

module KokugoTagger::Merger
	module_function
	def connect(yamcha, cabocha)
		read, write = IO.pipe("UTF-8")
		Thread.fork do
			self.process yamcha, cabocha, write
			write.close
		end.abort_on_exception = true
		return read
	end
	def process(yamcha, cabocha, output)
		cabocha.each_line do |line|
			if line[0] == "*"
				record = yamcha.gets
				record = yamcha.gets until record.chomp != ""
				letter = record.chomp.split("\t").last.upcase
				line.sub! /[A-Z]+/, letter
			end
			output.puts line
		end
	end
end

module KokugoTagger::Learner
	module_function
	def learn(source_dir, model, enc)
		model ||= "kokugo"
		convert source_dir, "train.data", enc
		yamcha_learn "train.data", model
	end
	def validation(source_dir, enc, k)
		convert source_dir, "train.data", enc
		filenames = split("train.data", enc, k)
		filenames.each_with_index do |filename, n|
			others = filenames - [filename]
			concat others, "temp.data"
			model = "test"
			yamcha_learn "temp.data", model
			result = "result.#{n}.data"
			system "cat #{filename} | yamcha -m test.model > #{result}"
		end
		data_set = []
		filenames = Array.new(k){|n| "result.#{n}.data"}
		filenames.each do |filename|
			sentence = 0
			chunk = 0
			accuracy = 0
			label_data = Hash.new{|h, k| h[k] = Hash.new(0)}
			File.foreach(filename, encoding: enc) do |line|
				line.chomp!
				if line.empty?
					sentence += 1
				else
					t, p = *line.split(/\s/)[-2, 2]
					acc = (t == p)
					chunk += 1
					accuracy += 1 if acc
					label_data[t][[true, acc]] += 1
					label_data[p][[acc, true]] += 1
				end
			end
			data_set << [sentence, chunk, accuracy, label_data]
		end
		report = open("validation.txt", "w:UTF-8")
		report.puts "# #{k}-fold cross-validation"
		report.puts 
		report.puts "## test files"
		k.times do |n|
			sentence, chunk = *data_set[n]
			report.puts "train.#{n}.data: #{sentence} sentences. #{chunk} chunks."
		end
		report.puts 
		k.times do |n|
			sentence, chunk, accuracy, label_data = *data_set[n]
			report.puts "## train.#{n}.data"
			report.puts "accuracy: #{accuracy.to_f / chunk}"
			report.puts "labels:"
			report.puts %w(label tp tn fp fn recall precision f-score accuracy).join("\t")
			label_data.sort.each do |label, data|
				tp = data[[true, true]]
				tn = data[[true, false]]
				fp = data[[false, true]]
				fn = chunk - (tp + tn + fp)
				recall = tp.to_f / (tp + tn)
				precision = tp.to_f / (tp + fp)
				f = 2 * precision * recall / (precision + recall)
				acc = (tp + fn).to_f / chunk
				report.puts %w(%s %d %d %d %d %.2f %.2f %.2f %.2f).join("\t") % [label, tp, tn, fp, fn, recall, precision, f, acc]
			end
			report.puts
		end
	end
	def convert(source_dir, target_filename, enc)
		target = open(target_filename, "w:#{enc}")
		source_filenames = Dir.glob(source_dir + "/*.cabocha")
		# source_filenames = source_filenames[0, 2] # debug
		source_filenames.each do |filename|
			source = open(filename, encoding: enc)
			converter = KokugoTagger::Converter.connect(source)
			converter.each_line{|line| target.puts line }
			source.close
		end
		target.close
	end
	def split(source_filename, enc, k)
		basename = File.basename(source_filename, ".data")
		target_filenames = Array.new(k){|n| "#{basename}.#{n}.data"}
		targets = target_filenames.map{|filename| open(filename, "w:#{enc}")}
		index = 0
		File.foreach(source_filename, encoding: enc) do |line|
			targets[index].puts line
			if line.chomp.empty?
				index += 1
				index = 0 if index == k
			end
		end
		targets.each{|f| f.close}
		return target_filenames
	end
	def concat(source_filenames, target_filename)
		system "cat #{source_filenames.join(" ")} > #{target_filename}"
	end
	def yamcha_learn(train_data, model)
		libexecdir = `yamcha-config --libexecdir`.chomp
		system "cp #{libexecdir}/Makefile ."
		system "make CORPUS=#{train_data} MODEL=#{model} FEATURE=\"F:0..0:1..\" SVM_PARAM=\"-t 1 -d 2 -c 1\" MULTI_CLASS=1 train"
	end
end

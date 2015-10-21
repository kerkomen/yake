#!/usr/bin/env ruby

require 'yaml'


LANG_EXTENSIONS = { 'python' => 'py', 'py' => 'py',
					'ruby' => 'rb', 'rb' => 'rb',
					'haskell' => 'hs', 'hs' => 'hs',
					'c' => 'c',
					'r' => 'r', 'rlang' => 'r',
					'javascript' => 'js', 'js' => 'js',
					'scala' => 'scala', 'scl' => 'scl'  }

LANG_EXEC = { 'python' => 'python', 'py' => 'python',
			  'ruby' => 'ruby', 'rb' => 'ruby',
			  'haskell' => 'runhaskell', 'hs' => 'runhaskell',
			  'r' => 'Rscript', 'rlang' => 'Rscript',
			  'javascript' => 'node', 'js' => 'node',
			  'scala' => 'scala', 'scl' => 'scala'  }

ABORT_MESSAGE = "Fix the errors and rerun yake."


# Yakefile should be provided as the first argument to yake.
# Otherwise, yake searches for the file named `Yakefile` 
#   in the current directory.
input_file = ARGV[0].nil? ? 'Yakefile' : ARGV[0]
begin
	input = YAML.load_file(input_file)
rescue => e
	puts e.backtrace.join("\n")
	if File.exist? input_file
		puts "The Yakefile provided is invalid."
	else
		puts "No valid Yakefile provided. No valid Yakefile found in the current directory."
		puts "There are files with .yake extension in the current directory:\n\t #{
			Dir.glob('*.yake').join("\n\t")
		}" if not Dir.glob('*.yake').empty?
	end
	abort ABORT_MESSAGE
end

# puts "Task names: #{input.keys.join(', ')}."

# Transformation rule:
#   $variable -> $(variable)
def add_parenth var
	var.gsub( /\$([\w\d_-]+)/, '$(\1)' )
end


# Prepare execution calls by replacing special variables
def prepare_new_exec(exec, inside)
	new_exec = exec.gsub( /\^([\w\d_-]+)/ ) { |e| inside[e[1..-1]] }
				   .gsub( /o@1/, inside[:targets][0] )  # first target
				   .gsub( /o@(\d)/ ) { |n| 
				       inside[:targets][n.split('@').last.to_i - 1] 
				   }                                    # all targets
				   .gsub( /i@1/, '$<' )       		    # first prerequisite
				   .gsub( /i@(\d)/) { |n|
				   		inside[:prerequisites][n.split('@').last.to_i - 1]
				   	}  		                            # all prerequisites
				   .gsub( /(\$\(.+\))/, '$\1' )  	    # $(shell call) -> $$(shell call)
				   .gsub( /\$([\w\d_-]+)/, '$(\1)' )    # $variable -> $(variable)
	new_exec
end

# Pack the given code to a script file
def pack_script( code, name, num, lang='sh' )

	dir = 'yakescripts'
	Dir.mkdir(dir) unless File.directory? 'yakescripts'

	lang_extension  = LANG_EXTENSIONS[lang]
	script_filename = dir + '/' + name + '_' + num.to_s + '.' + lang_extension
	s = File.write(script_filename, code)

	return script_filename

end

# To store the flags that should be explicitely declared in the Makefile
flags_as_targets = {}

# Header message for the output
header_notice = <<HEADER
# Generated with yake
# Read more: https://goo.gl/C00Rs9
HEADER

puts header_notice

input.keys.each do |task|

	# Special tasks
	#   let: defines the global variables
	#   TODO
	special_tasks = ['let']
	if special_tasks.member? task

		case task
		when 'let'
			puts "\n\n# Global variables\n"
			defs = input[task]
			defs.keys.each do |var|
				defs[var] = defs[var]
				puts "#{var}:=#{defs[var]}\n"
			end
		end
		next

	end

	defs = input[task]
	inside = {}
	task_exec_count = 0

	task_flag = ".#{task}.yakeflag"

	begin
		(prereqs, targets) = defs['io'].split('->').map(&:strip)
		inside[:prerequisites] = prereqs.split(' ').map(&:strip)
		inside[:targets] = targets.split(' ').map(&:strip)
	rescue => e
		puts e.backtrace.join("\n")
		puts "Every rule should contain `io` definition in the form: \n\tprereq1 [prereq2 ...] -> target1 [target2 ...]"
	end

	# Description -> Comment above the rule
	# Pound signs are appended to multiline comment lines
	puts "\n\n"
	puts "\# #{defs['descr'].gsub(/(\n)(.+)/, '\1# \2')}" if defs.has_key? 'descr'
	puts "\# #{defs['description'].gsub(/(\n)(.+)/, '\1# \2')}" if defs.has_key? 'description'

	# Process rule prerequisites
	inside[:prerequisites].map! do |pr|
		if pr.start_with?('^')
			flags_as_targets[pr] = inside[:targets][0]
			flags_as_targets[pr] = add_parenth(flags_as_targets[pr]) if flags_as_targets[pr].start_with?('$')
			fail "The flag `-f` (`--flags-only`) is required to use a rule name as a prerequisite. Not implemented yet."
			".#{pr[1..-1]}.yakeflag"
		else
			pr.start_with?('$') ? add_parenth(pr) : pr
		end
	end
	
	# Process rule targets
	if inside[:targets].length > 1
		puts "#{task_flag}: #{inside[:prerequisites].join(' ')}"
		# targets will be added later on with flag as a prerequisite
	elsif inside[:targets].length == 1
		tar = inside[:targets][0]
		tar = add_parenth(tar) if tar.start_with?('$')
		puts "#{tar}: #{inside[:prerequisites].join(' ')}"
	else
		warning "No targets detected in the task `#{task}'"
		abort ABORT_MESSAGE
	end


	# If copy definition is present copy other definitions
	if defs['copy']
		defs['copy_after'] = defs['copy']  # default is copy_after
	end

	# Copy external rules after the original ones
	if defs['copy_after']
		rule_to_copy = defs['copy_after'].strip
		begin
			external_rule = input[rule_to_copy]
			external_rule.keys.each do |external_def|
				if external_def == 'let'
					defs['let'] = defs['let'].merge( external_rule['let'] )
				elsif external_def != 'io'
					defs[external_def] ||= []
					defs[external_def] += external_rule[external_def]
				end
			end
		rescue => e
			puts e.backtrace.join("\n")
		end
	end

	# Copy external rules before the original ones
	if defs['copy_before']
		rule_to_copy = defs['copy_before'].strip
		begin
			external_rule = input[rule_to_copy]
			external_rule.keys.each do |external_def|
				if external_def == 'let'
					defs['let'] = external_rule['let'].merge( defs['let'] )
				elsif external_def != 'io'
					defs[external_def] ||= []
					defs[external_def] = external_rule[external_def] + defs[external_def]
				end
			end
		rescue => e
			puts e.backtrace.join("\n")
		end
	end


	# Use substitution variables
	defs['let'].each do |var, internal|

		begin
			internal.gsub!( /\^([\w\d_]+)/ ) { |e| inside[e[1..-1]] }
			inside[var] = internal
		rescue TypeError => e
			puts e.backtrace.join("\n")
			puts "Something's wrong with the variable substitution. Make sure that that the definition `#{var}: #{internal}' points only to variables that were already defined."
			abort ABORT_MESSAGE
		end
		inside[var] = internal

	end if defs['let']

	# Put shell commands substituting variables
	defs['sh'].each do |exec|

		new_exec = prepare_new_exec exec, inside
		
		puts "\t#{new_exec}"
		task_exec_count += 1

	end if defs['sh']


	##########
	# Process code for specific languages
	##########
	#
	LANG_EXTENSIONS.keys.each do |lang_ext|
		if defs.keys.member? lang_ext

			if_compiled = nil
			defs[lang_ext].each do |e|
				if e.is_a?(Hash) and e.keys.member?('compile')
					if_compiled = e['compile']
					break
				end
			end
			defs[lang_ext].reject! { |e| e.is_a? Hash }

			defs[lang_ext].each do |exec|
				task_exec_count += 1
				new_exec = prepare_new_exec exec, inside
				run_exec = pack_script(new_exec, task, task_exec_count, lang_ext)
				if if_compiled and not if_compiled.empty?
					puts "\t#{if_compiled} #{run_exec}"
					puts "\t#{run_exec.split('.')[0...-1].join('.')}"
				else
					puts "\t#{LANG_EXEC[lang_ext]} #{run_exec}"
				end
			end

		end
	end



	puts "\ttouch #{task_flag}"


	# Multiple targets case: use flag
	if inside[:targets].length > 1

		puts "\n"
		inside[:targets].each do |t|
			puts "#{t}: #{task_flag}"
			puts "\n"
		end

	end

end

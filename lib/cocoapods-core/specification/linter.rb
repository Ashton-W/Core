module Pod
  class Specification

    # The Linter check specifications for errors, warnings, and deprecations.
    #
    # It is designed not only to guarantee the formal functionality of a
    # specification, but also to support the maintenance of sources.
    #
    class Linter

      # @return [Specification] the specification to lint.
      #
      attr_reader :spec

      # @return [Pathname] the path of the `podspec` file where {#spec} is
      #         defined.
      #
      attr_reader :file

      # @param  [Specification, Pathname, String] spec_or_path
      #         the Specification or the path of the `podspec` file to lint.
      #
      def initialize(spec_or_path)
        if spec_or_path.is_a?(Specification)
          @spec = spec_or_path
          @file = @spec.defined_in_file
        else
          @file = Pathname.new(spec_or_path)
          begin
            @spec = Specification.from_file(@file)
          rescue Exception => e
            @spec = nil
          end
        end
      end

      # Lints the specification adding a {Result} for any failed check to the
      # {#results} list.
      #
      # @return [Bool] whether the specification passed validation.
      #
      def lint
        unless spec
          error "The specification could not be loaded.\n#{e.message}\n#{e.backtrace}"
        end
        @results = []
        perform_textual_analysis
        check_required_root_attributes
        run_root_validation_hooks
        perform_all_specs_ananlysis
        results.empty?
      end

      #-----------------------------------------------------------------------#

      # !@group Lint results

      public

      # @return [Array<Result>] all the results generated by the Linter.
      #
      attr_reader :results

      # @return [Array<Result>] all the errors generated by the Linter.
      #
      def errors
        @errors ||= results.select { |r| r.type == :error }
      end

      # @return [Array<Result>] all the warnings generated by the Linter.
      #
      def warnings
        @warnings ||= results.select { |r| r.type == :warning }
      end

      # @return [Array<Result>] all the deprecations generated by the Linter.
      #
      def deprecations
        @deprecations ||= results.select { |r| r.type == :deprecation }
      end

      #-----------------------------------------------------------------------#

      private

      # !@group Lint steps

      # It reads a podspec file and checks for strings corresponding
      # to features that are or will be deprecated
      #
      # @return [void]
      #
      def perform_textual_analysis
        return unless @file
        text = @file.read
        deprecation "`config.ios?' and `config.osx?' are deprecated." if text. =~ /config\..?os.?/
        deprecation "clean_paths are deprecated (use preserve_paths)." if text. =~ /clean_paths/
        error "Comments must be deleted." if text.scan(/^\s*#/).length > 24
      end

      # Checks that every root only attribute which is required has a value.
      #
      # @return [void]
      #
      def  check_required_root_attributes
        attributes = DSL.attributes.select(&:root_only?)
        attributes.each do |attr|
          value = spec.send(attr.reader_name)
          next unless attr.required?
          unless value && (!value.respond_to?(:empty?) || !value.empty?)
            error("Missing required attribute `#{attr.name}`.")
          end
        end
      end

      # Runs the validation hook for root only attributes.
      #
      # @return [void]
      #
      def run_root_validation_hooks
        attributes = DSL.attributes.select(&:root_only?)
        run_validation_hooks(attributes)
      end

      # Run validations for multi-platform attributes activating .
      #
      # @return [void]
      #
      def perform_all_specs_ananlysis
        all_specs = [ spec, *spec.recursive_subspecs ]
        all_specs.each do |current_spec|
          @current_spec = current_spec
          platforms = current_spec.available_platforms
          platforms.each do |platform|
            @current_platform = platform
            current_spec.activate_platform(platform)

            run_all_specs_valudation_hooks
            validate_file_patterns
            check_tmp_arc_not_nil
            check_if_spec_is_empty
          end
        end
      end

      # @return [Specification] the current (sub)spec being validated.
      #
      attr_reader :current_spec

      # @return [Symbol] the name of the platform being validated.
      #
      attr_accessor :current_platform

      # Runs the validation hook for the attributes that are not root only.
      #
      # @return [void]
      #
      def run_all_specs_valudation_hooks
        attributes = DSL.attributes.reject(&:root_only?)
        run_validation_hooks(attributes)
      end

      # Runs the validation hook for each attribute.
      #
      # @note   Hooks are called only if there is a value for the attribute as
      #         required attributes are already checked by the
      #         {#check_required_root_attributes} step.
      #
      # @return [void]
      #
      def run_validation_hooks(attributes)
        attributes.each do |attr|
          validation_hook = "_validate_#{attr.name}"
          next unless respond_to?(validation_hook, true)
          value = spec.send(attr.reader_name)
          next unless value
          send(validation_hook, value)
        end
      end

      #-----------------------------------------------------------------------#

      private

      # @!group Root spec validation helpers

      # Performs validations related to the `name` attribute.
      #
      def _validate_name(n)
        if spec.name && file
          names_match = (file.basename.to_s == spec.root.name + '.podspec')
          unless names_match
            error "The name of the spec should match the name of the file."
          end
        end
      end

      # Performs validations related to the `summary` attribute.
      #
      def _validate_summary(s)
        warning "The summary should be short use `description` (max 140 characters)." if s.length > 140
        warning "The summary is not meaningful." if s =~ /A short description of/
        warning "The summary should end with proper punctuation." if s !~ /(\.|\?|!)$/
      end

      # Performs validations related to the `description` attribute.
      #
      def _validate_description(d)
        warning "The description is not meaningful." if d =~ /An optional longer description of/
        warning "The description should end with proper punctuation." if d !~ /(\.|\?|!)$/
        warning "The description is equal to the summary." if d == spec.summary
        warning "The description is shorter than the summary." if d.length < spec.summary.length
      end

      # Performs validations related to the `license` attribute.
      #
      def _validate_license(l)
        type = l[:type]
        warning "Missing license type." if type.nil?
        warning "Sample license type."  if type && type =~ /\(example\)/
        warning "Invalid license type." if type && type.gsub(' ', '').gsub("\n", '').empty?
      end

      # Performs validations related to the `source` attribute.
      #
      def _validate_source(s)
        if git = s[:git]
          tag, commit = s.values_at(:tag, :commit)
          github      = git.include?('github.com')
          version     = spec.version.to_s

          error "Example source." if git =~ /http:\/\/EXAMPLE/
          error 'The commit of a Git source cannot be `HEAD`.'    if commit && commit.downcase =~ /head/
          warning 'The version should be included in the Git tag.' if tag && !tag.include?(version)
          warning "Github repositories should end in `.git`."      if github && !git.end_with?('.git')
          warning "Github repositories should use `https` link."   if github && !git.start_with?('https://github.com') && !git.start_with?('git://gist.github.com')

          if version == '0.0.1'
            warning 'Git sources should specify either a commit or a tag.' if commit.nil? && tag.nil?
          else
            warning 'Git sources should specify a tag.' if tag.nil?
          end
        end
      end

      #-----------------------------------------------------------------------#

      # @!group All specs validation helpers

      private

      # Performs validations related to the `compiler_flags` attribute.
      #
      def _validate_compiler_flags(flags)
        if flags.join(' ').split(' ').any? { |flag| flag.start_with?('-Wno') }
          warning "Warnings must not be disabled (`-Wno' compiler flags)."
        end
      end

      # Checks the attributes that represent file patterns.
      #
      def validate_file_patterns
        attributes = DSL.attributes.select(&:file_patterns?)
        attributes.each do |attrb|
          patterns = spec.send(attrb.reader_name)
          patterns = patterns.is_a?(Hash) ? patterns.values : patterns
          patterns = patterns.flatten
          patterns.each do |pattern|
            if defined?(Rake) && pattern.is_a?(Rake::FileList)
              deprecation "Rake::FileList is deprecated, use `exclude_files` (#{attrb.name})."
            else
              if pattern.start_with?('/')
                error "File patterns must be relative and cannot start with a slash (#{attrb.name})."
              end
            end
          end
        end
      end

      # @todo remove in 0.18 and switch the default to true.
      #
      def check_tmp_arc_not_nil
        if spec.requires_arc.nil?
          warning "A value for `requires_arc` should be specified until the migration to a `true` default."
        end
      end

      # Check empty subspec attributes
      #
      def check_if_spec_is_empty
        methods = %w[ source_files resources preserve_paths subspecs ]
        empty = methods.all? { |m| spec.send(m).empty? }
        if empty
          error "The spec appears to be empty (no source files, resources, or preserve paths)."
        end
      end

      #-----------------------------------------------------------------------#

      # !@group Result Helpers

      private

      # Adds an error result with the given message.
      #
      # @param  [String] message
      #         The message of the result.
      #
      # @return [void]
      #
      def error(message)
        add_result(:error, message)
      end

      # Adds an warning result with the given message.
      #
      # @param  [String] message
      #         The message of the result.
      #
      # @return [void]
      #
      def warning(message)
        add_result(:warning, message)
      end

      # Adds an deprecation result with the given message.
      #
      # @param  [String] message
      #         The message of the result.
      #
      # @return [void]
      #
      def deprecation(message)
        add_result(:deprecation, message)
      end

      # Adds a result of the given type with the given message. If there is a
      # current platform it is added to the result. If a result with the same
      # type and the same message is already available the current platform is
      # added to the existing result.
      #
      # @param  [Symbol] type
      #         The type of the result (`:error`, `:warning`, `:deprecation`).
      #
      # @param  [String] message
      #         The message of the result.
      #
      # @return [void]
      #
      def add_result(type, message)
        result = results.find { |r| r.type == type && r.message == message }
        unless result
          result = Result.new(type, message)
          results << result
        end
        result.platforms << current_platform.name if current_platform
      end

      #-----------------------------------------------------------------------#

      class Result

        # @return [Symbol] the type of result.
        #
        attr_reader :type

        # @return [String] the message associated with result.
        #
        attr_reader :message

        # @param [Symbol] type    @see type
        # @param [String] message @see message
        #
        def initialize(type, message)
          @type    = type
          @message = message
          @platforms = []
        end

        # @return [Array<Platform>] the platforms where this result was
        #         generated.
        #
        attr_reader :platforms

        # @return [String] a string representation suitable for UI output.
        #
        def to_s
          r = "[#{type.to_s.upcase}] #{message}"
          if platforms != Specification::PLATFORMS
            platforms_names = platforms.uniq.map { |p| Platform.string_name(p) }
            r << " [#{platforms_names * ' - '}]" unless platforms.empty?
          end
          r
        end
      end

      #-----------------------------------------------------------------------#

    end
  end
end

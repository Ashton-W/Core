require File.expand_path('../spec_helper', __FILE__)

module Pod
  describe Source do
    before do
      @path = fixture('spec-repos/test_repo')
      @source = Source.new(@path)
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      it 'return its name' do
        @source.name.should == 'test_repo'
      end

      it 'return its type' do
        @source.type.should == 'file system'
      end

      it 'can be ordered according to its name' do
        s1 = Source.new(Pathname.new 'customized')
        s2 = Source.new(Pathname.new 'master')
        s3 = Source.new(Pathname.new 'private')
        [s3, s1, s2].sort.should == [s1, s2, s3]
      end
    end

    #-------------------------------------------------------------------------#

    describe '#pods' do
      it 'returns the available Pods' do
        @source.pods.should == %w(BananaLib Faulty_spec IncorrectPath JSONKit JSONSpec)
      end

      it "raises if the repo doesn't exists" do
        @path = fixture('spec-repos/non_existing')
        @source = Source.new(@path)
        should.raise Informative do
          @source.pods
        end.message.should.match /Unable to find a source named: `non_existing`/
      end
    end

    #-------------------------------------------------------------------------#

    describe '#versions' do
      it 'returns the available versions of a Pod' do
        @source.versions('JSONKit').map(&:to_s).should == ['999.999.999', '1.13', '1.4']
      end

      it 'returns nil if the Pod could not be found' do
        @source.versions('Unknown_Pod').should.be.nil
      end
    end

    #-------------------------------------------------------------------------#

    describe '#specification' do
      it 'returns the specification for the given name and version' do
        spec = @source.specification('JSONKit', Version.new('1.4'))
        spec.name.should == 'JSONKit'
        spec.version.should.to_s == '1.4'
      end
    end

    #-------------------------------------------------------------------------#

    describe '#all_specs' do
      it 'returns all the specifications' do
        expected = %w(BananaLib IncorrectPath JSONKit JSONSpec)
        @source.all_specs.map(&:name).sort.uniq.should == expected
      end
    end

    #-------------------------------------------------------------------------#

    describe '#set' do
      it 'returns the set of a given Pod' do
        set = @source.set('BananaLib')
        set.name.should == 'BananaLib'
        set.sources.should == [@source]
      end
    end

    #-------------------------------------------------------------------------#

    describe '#pod_sets' do
      it 'returns all the pod sets' do
        expected = %w(BananaLib Faulty_spec IncorrectPath JSONKit JSONSpec)
        @source.pod_sets.map(&:name).sort.uniq.should == expected
      end
    end

    #-------------------------------------------------------------------------#

    describe '#search' do
      it 'searches for the Pod with the given name' do
        @source.search('BananaLib').name.should == 'BananaLib'
      end

      it 'searches for the pod with the given dependency' do
        dep = Dependency.new('BananaLib')
        @source.search(dep).name.should == 'BananaLib'
      end

      it 'supports dependencies on subspecs' do
        dep = Dependency.new('BananaLib/subspec')
        @source.search(dep).name.should == 'BananaLib'
      end

      it 'matches case' do
        @source.search('bAnAnAlIb').should.be.nil?
      end

      describe '#search_by_name' do
        it 'properly configures the sources of a set in search by name' do
          source = Source.new(fixture('spec-repos/test_repo'))
          sets = source.search_by_name('monkey', true)
          sets.count.should == 1
          set = sets.first
          set.name.should == 'BananaLib'
          set.sources.map(&:name).should == %w(test_repo)
        end

        it 'can use regular expressions' do
          source = Source.new(fixture('spec-repos/test_repo'))
          sets = source.search_by_name('mon[ijk]ey', true)
          sets.first.name.should == 'BananaLib'
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe '#search_by_name' do
      it 'supports full text search' do
        sets = @source.search_by_name('monkey', true)
        sets.map(&:name).should == ['BananaLib']
        sets.map(&:sources).should == [[@source]]
      end

      it 'The search is case insensitive' do
        pods = @source.search_by_name('MONKEY', true)
        pods.map(&:name).should == ['BananaLib']
      end

      it 'supports partial matches' do
        pods = @source.search_by_name('MON', true)
        pods.map(&:name).should == ['BananaLib']
      end

      it "handles gracefully specification which can't be loaded" do
        should.raise Informative do
          @source.specification('Faulty_spec', '1.0.0')
        end.message.should.include 'Invalid podspec'

        should.not.raise do
          @source.search_by_name('monkey', true)
        end
      end
    end

    #-------------------------------------------------------------------------#

    describe '#fuzzy_search' do
      it 'is case insensitive' do
        @source.fuzzy_search('bananalib').name.should == 'BananaLib'
      end

      it 'matches misspells' do
        @source.fuzzy_search('banalib').name.should == 'BananaLib'
      end

      it 'matches suffixes' do
        @source.fuzzy_search('Lib').name.should == 'BananaLib'
      end

      it 'returns nil if there is no match' do
        @source.fuzzy_search('12345').should.be.nil
      end

      it 'matches abbreviations' do
        @source.fuzzy_search('BLib').name.should == 'BananaLib'
      end
    end

    #-------------------------------------------------------------------------#

    describe 'Representations' do
      it 'returns the hash representation' do
        @source.to_hash['BananaLib']['1.0']['name'].should == 'BananaLib'
      end

      it 'returns the yaml representation' do
        yaml = @source.to_yaml
        yaml.should.match /---/
        yaml.should.match /BananaLib:/
      end
    end

    #-------------------------------------------------------------------------#

    before do
      path = fixture('spec-repos/test_repo')
      @source = Source.new(path)
    end

    #-------------------------------------------------------------------------#

    describe 'In general' do
      it 'returns its name' do
        @source.name.should == 'test_repo'
      end
    end

    #-------------------------------------------------------------------------#

    describe '#pods' do
      it 'returns the available Pods' do
        @source.pods.should == %w(BananaLib Faulty_spec IncorrectPath JSONKit JSONSpec)
      end

      it 'raises if the repo does not exist' do
        path = fixture('spec-repos/non_existing')
        @source = Source.new(path)
        should.raise Informative do
          @source.pods
        end.message.should.match /Unable to find a source named: `non_existing`/
      end

      it "doesn't include the `.` and the `..` dir entries" do
        @source.pods.should.not.include?('.')
        @source.pods.should.not.include?('..')
      end

      it 'only consider directories' do
        File.stubs(:directory?).returns(false)
        @source.pods.should == []
      end

      it 'uses the `Specs` dir if it is present' do
        @source.send(:specs_dir).to_s.should.end_with('test_repo/Specs')
      end

      it 'uses the root of the repo as the specs dir if the `Specs` folder is not present' do
        repo = fixture('spec-repos/master')
        @source = Source.new(repo)
        @source.send(:specs_dir).to_s.should.end_with('master')
      end
    end

    #-------------------------------------------------------------------------#

    describe '#versions' do
      it 'returns the versions for the given Pod' do
        @source.versions('JSONKit').map(&:to_s).should == ['999.999.999', '1.13', '1.4']
      end

      it 'returns nil the Pod is unknown' do
        @source.versions('Unknown_Pod').should.be.nil
      end

      it 'raises if the name of the Pod is not provided' do
        should.raise ArgumentError do
          @source.versions(nil)
        end.message.should.match /No name/
      end

      it 'raises if a non-version-name directory is encountered' do
        Pathname.any_instance.stubs(:children).returns([Pathname.new('/Hello')])
        Pathname.any_instance.stubs(:directory?).returns(true)
        e = lambda { @source.versions('JSONKit') }.should.raise Informative
        e.message.should.match /Hello/
        e.message.should.not.match /Malformed version number string/
      end
    end

    #-------------------------------------------------------------------------#

    describe '#specification' do
      it 'returns the specification for the given version of a Pod' do
        spec = @source.specification('JSONKit', '1.4')
        spec.name.should == 'JSONKit'
        spec.version.to_s.should == '1.4'
      end

      it 'returns nil if the Pod is unknown' do
        should.raise StandardError do
          @source.specification('Unknown_Pod', '1.4')
        end.message.should.match /Unable to find the specification Unknown_Pod/
      end

      it "raises if the version of the Pod doesn't exists" do
        should.raise StandardError do
          @source.specification('JSONKit', '0.99.0')
        end.message.should.match /Unable to find the specification JSONKit/
      end

      it 'raises if the name of the Pod is not provided' do
        should.raise ArgumentError do
          @source.specification(nil, '1.4')
        end.message.should.match /No name/
      end

      it 'raises if the name of the Pod is not provided' do
        should.raise ArgumentError do
          @source.specification('JSONKit', nil)
        end.message.should.match /No version/
      end
    end

    #-------------------------------------------------------------------------#

    describe '#specification_path' do
      it 'returns the path of a specification' do
        path = @source.specification_path('JSONKit', '1.4')
        path.to_s.should.end_with?('test_repo/Specs/JSONKit/1.4/JSONKit.podspec')
      end

      it 'prefers JSON podspecs if one exists' do
        Pathname.any_instance.stubs(:exist?).returns(true)
        path = @source.specification_path('JSONSpec', '0.9')
        path.to_s.should.end_with?('Specs/JSONSpec/0.9/JSONSpec.podspec.json')
      end

      it 'raises if the name of the Pod is not provided' do
        should.raise ArgumentError do
          @source.specification_path(nil, '1.4')
        end.message.should.match /No name/
      end

      it 'raises if the name of the Pod is not provided' do
        should.raise ArgumentError do
          @source.specification_path('JSONKit', nil)
        end.message.should.match /No version/
      end
    end

    #-------------------------------------------------------------------------#
  end
end

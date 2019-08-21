require 'spec_helper'
require 'riveter/core_extensions'

describe Riveter::CoreExtensions do
  describe Riveter::CoreExtensions::BooleanSupport do
    it { Object.should respond_to(:boolean?) }
    it { Object.should respond_to(:to_b) }

    it { true.boolean?.should be_truthy }
    it { false.boolean?.should be_truthy }
    it { Object.new().boolean?.should be_falsey }

    [true, 1, 'yes', 'on', 'y', '1'].each do |value|
      it { value.to_b.should be_truthy }
    end

    [false, 0, 'no', 'off', 'n', '0'].each do |value|
      it { value.to_b.should be_falsey }
    end
  end

  describe Riveter::CoreExtensions::DateExtensions do
    it { Date.should respond_to(:system_start_date) }
    it { Date.should respond_to(:from_utc_ticks) }
    it { Date.new().should respond_to(:to_utc_ticks) }

    it { Date.system_start_date.should eq(Date.new(1970, 1, 1)) }
    it { Date.from_utc_ticks(0).should eq(Date.new(1970, 1, 1)) }
    it { Date.from_utc_ticks(86_400_000).should eq(Date.new(1970, 1, 2)) }
    it { Date.new(1970, 1, 1).to_utc_ticks.should eq(0) }
  end

  describe Riveter::CoreExtensions::ArrayExtensions do
    subject { [1, 2, 3, 4] }

    describe "#cumulative_sum" do
      it { should respond_to(:cumulative_sum) }

      it { subject.cumulative_sum.should eq([1, 3, 6, 10]) }
    end

    describe "#nil_sum" do
      it { should respond_to(:nil_sum) }

      it { subject.nil_sum.should eq(10) }
      it { subject.nil_sum(20).should eq(30) }

      it { [1, 2, nil, 4].nil_sum.should eq(7) }
      it { [1, 2, nil, 4].nil_sum(10).should eq(17) }

      it {
        block = Mock::Block.new()
        expect(block).to receive(:call).exactly(4).times { 2 }
        [1, 2, 3, 4].nil_sum(&block).should eq(8)
      }
    end

    describe "#average" do
      it { should respond_to(:average) }

      it { subject.average.should eq(2.5) }
    end

    describe "#variance" do
      it { should respond_to(:variance) }

      it { subject.variance.should eq(1.6666666666666667) }
    end

    describe "#standard_deviation" do
      it { should respond_to(:standard_deviation) }

      it { subject.standard_deviation.should eq(1.2909944487358056) }
    end

    describe "#to_hash_for" do
      it { should respond_to(:to_hash_for) }

      it { subject.to_hash_for.should eq({1 => 1, 2 => 2, 3 => 3, 4 => 4}) }
      it { subject.to_hash_for(&:to_s).should eq({'1' => 1, '2' => 2, '3' => 3, '4' => 4}) }
    end

    describe "#round" do
      it { should respond_to(:round) }

      it { subject.round(6).should eq([1, 2, 3, 4]) }
      it { [1.456789, 2.987654].round(2).should eq([1.46, 2.99]) }
    end

    describe "#find_each_with_order" do
      it { should respond_to(:find_each_with_order) }
      it { should respond_to(:find_each) }

      it "should invoke block" do
        block = Mock::Block.new()
        expect(block).to receive(:call).exactly(4).times
        subject.find_each_with_order(&block)
      end

      it "should not invoke block" do
        block = Mock::Block.new()
        expect(block).to_not receive(:call)
        [].find_each_with_order(&block)
      end
    end
  end

  describe Riveter::CoreExtensions::HashExtensions do
    describe "#rmerge" do
      it {
        h1 = {"a" => 100, "b" => 200, "c" => {"c1" => 12, "c2" => 14}, "d" => {"d1" => 400}}
        h2 = {"b" => 254, "c" => 300, "c" => {"c1" => 16, "c3" => 94}, "d" => nil}
        h1.rmerge(h2).should eq({"a" => 100, "b" => 254, "c" => {"c1" => 16, "c2" => 14, "c3" => 94}, "d" => nil})
      }
    end

    describe "#rmerge!" do
      it {
        h1 = {"a" => 100, "b" => 200, "c" => {"c1" => 12, "c2" => 14}}
        h2 = {"b" => 254, "c" => 300, "c" => {"c1" => 16, "c3" => 94}}
        h1.rmerge!(h2)
        h1.should eq({"a" => 100, "b" => 254, "c" => {"c1" => 16, "c2" => 14, "c3" => 94}})
      }
    end
  end

  describe Riveter::CoreExtensions::ChainedQuerySupport do
    subject do
      Class.new().class_eval do
        include Riveter::CoreExtensions::ChainedQuerySupport
      end.new()
    end

    it { should respond_to(:where?) }
    it { subject.where?(false, {}).should eq(subject) }
    it {
      expect(subject).to receive(:where).with({:a => 'v'})
      subject.where?(true, {:a => 'v'})
    }
  end

  describe Riveter::CoreExtensions::BatchFinderSupport do
    subject do
      Class.new(Array).class_eval do
        include Riveter::CoreExtensions::BatchFinderSupport

        def limit(*args)
          @limit = args.first
          self
        end

        def offset(*args)
          self.shift(@limit)
        end

        self
      end.new().concat((1..2000).to_a)
    end

    describe "#find_each_with_order" do
      it { should respond_to(:find_each_with_order) }

      it "should invoke block for each element" do
        block = Mock::Block.new()
        expect(block).to receive(:call).exactly(subject.length).times
        subject.find_each_with_order(&block)
      end

      it "should return enumerator if no block given" do
        block = Mock::Block.new()
        expect(block).to receive(:call).exactly(subject.length).times
        subject.find_each_with_order.each(&block)
      end

      context "with overridden batch size" do
        let(:batch_size) { 10 }

        it "should invoke block for each element" do
          block = Mock::Block.new()
          expect(block).to receive(:call).exactly(subject.length).times
          expect(subject).to receive(:find_in_batches_with_order).with(:batch_size => batch_size).and_call_original
          subject.find_each_with_order(:batch_size => batch_size, &block)
        end

        it "should return enumerator if no block given" do
          block = Mock::Block.new()
          expect(block).to receive(:call).exactly(subject.length).times
          expect(subject).to receive(:find_in_batches_with_order).with(:batch_size => batch_size).and_call_original
          subject.find_each_with_order(:batch_size => batch_size).each(&block)
        end
      end
    end

    describe "#find_in_batches_with_order" do
      it { should respond_to(:find_in_batches_with_order) }

      it "should invoke block for each element" do
        block = Mock::Block.new()
        expect(block).to receive(:call).exactly(subject.length / 1000).times
        subject.find_in_batches_with_order(&block)
      end

      it "should return enumerator if no block given" do
        block = Mock::Block.new()
        expect(block).to receive(:call).exactly(subject.length / 1000).times
        subject.find_in_batches_with_order.each(&block)
      end

      context "with overridden batch size" do
        let(:batch_size) { 10 }

        it "should invoke block for each element" do
          block = Mock::Block.new()
          expect(block).to receive(:call).exactly(subject.length / batch_size).times
          subject.find_in_batches_with_order(:batch_size => batch_size, &block)
        end

        it "should return enumerator if no block given" do
          block = Mock::Block.new()
          expect(block).to receive(:call).exactly(subject.length / batch_size).times
          subject.find_in_batches_with_order(:batch_size => batch_size).each(&block)
        end
      end
    end
  end
end
